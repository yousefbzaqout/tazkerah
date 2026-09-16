<?php

namespace Tests\Feature;

use App\Models\Event;
use App\Models\EventPolicyChunk;
use App\Models\ScanLog;
use App\Models\Seat;
use App\Models\Sector;
use App\Models\Ticket;
use App\Support\TenantContext;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Concerns\InteractsWithTenantRls;
use Tests\TestCase;

/**
 * R4 / FR-016 adversarial suite — cross-tenant leak attempts on all FORCE-RLS tables.
 */
class TenantRlsAdversarialTest extends TestCase
{
    use InteractsWithTenantRls;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->skipUnlessPgsql();
    }

    public function test_r4_empty_guc_fail_closed_on_all_rls_tables(): void
    {
        $tenant = $this->insertTenant('Tenant');
        $event = $this->insertEvent($tenant);
        $bundle = $this->insertSectorAndSeat($tenant, $event);
        $ticket = $this->insertSoldTicket($tenant, $bundle['seat_id'], (string) Str::uuid());
        $this->insertScanLog($tenant, $ticket);
        $this->insertPolicyChunk($tenant, $event);

        $this->beginAppRoleTransaction();
        TenantContext::clear();

        foreach (['events', 'sectors', 'seats', 'tickets', 'scan_logs', 'event_policy_chunks'] as $table) {
            $this->assertSame(0, DB::table($table)->count(), "R4: {$table} empty without tenant GUC");
        }

        $this->assertSame(0, Event::query()->count());
        $this->assertSame(0, Sector::query()->count());
        $this->assertSame(0, Seat::query()->count());
        $this->assertSame(0, Ticket::query()->count());
        $this->assertSame(0, ScanLog::query()->count());
        $this->assertSame(0, EventPolicyChunk::query()->count());

        DB::rollBack();
        TenantContext::resetRole();
    }

    public function test_r4_cross_tenant_matrix_select_update_delete_insert(): void
    {
        $tenantA = $this->insertTenant('A');
        $tenantB = $this->insertTenant('B');

        $eventA = $this->insertEvent($tenantA, 'A');
        $eventB = $this->insertEvent($tenantB, 'B');
        $seatA = $this->insertSectorAndSeat($tenantA, $eventA, 'A-1');
        $seatB = $this->insertSectorAndSeat($tenantB, $eventB, 'B-1');
        $ticketA = $this->insertSoldTicket($tenantA, $seatA['seat_id'], (string) Str::uuid());
        $ticketB = $this->insertSoldTicket($tenantB, $seatB['seat_id'], (string) Str::uuid());
        $logA = $this->insertScanLog($tenantA, $ticketA);
        $logB = $this->insertScanLog($tenantB, $ticketB);
        $chunkA = $this->insertPolicyChunk($tenantA, $eventA);
        $chunkB = $this->insertPolicyChunk($tenantB, $eventB);

        $this->beginAppRoleTransaction();
        TenantContext::set($tenantA);

        $this->assertSame([$eventA], DB::table('events')->pluck('id')->all());
        $this->assertSame([$seatA['sector_id']], DB::table('sectors')->pluck('id')->all());
        $this->assertSame([$seatA['seat_id']], DB::table('seats')->pluck('id')->all());
        $this->assertSame([$ticketA], DB::table('tickets')->pluck('id')->all());
        $this->assertSame([$logA], DB::table('scan_logs')->pluck('id')->all());
        $this->assertSame([$chunkA], DB::table('event_policy_chunks')->pluck('id')->all());

        $this->assertNotContains($eventB, Event::query()->pluck('id')->all());
        $this->assertNotContains($seatB['sector_id'], Sector::query()->pluck('id')->all());
        $this->assertNotContains($ticketB, Ticket::query()->pluck('id')->all());
        $this->assertNotContains($chunkB, EventPolicyChunk::query()->pluck('id')->all());

        $this->assertSame(0, DB::table('events')->where('id', $eventB)->update(['title' => 'x']));
        $this->assertSame(0, DB::table('sectors')->where('id', $seatB['sector_id'])->update(['name' => 'x']));
        $this->assertSame(0, DB::table('seats')->where('id', $seatB['seat_id'])->update(['status' => 'SOLD']));
        $this->assertSame(0, DB::table('tickets')->where('id', $ticketB)->update(['status' => 'REVOKED']));
        $this->assertSame(0, DB::table('scan_logs')->where('id', $logB)->update(['result' => 'INVALID']));
        $this->assertSame(0, DB::table('event_policy_chunks')->where('id', $chunkB)->update(['content' => 'x']));

        $this->assertSame(0, DB::table('events')->where('id', $eventB)->delete());
        $this->assertSame(0, DB::table('sectors')->where('id', $seatB['sector_id'])->delete());
        $this->assertSame(0, DB::table('seats')->where('id', $seatB['seat_id'])->delete());
        $this->assertSame(0, DB::table('tickets')->where('id', $ticketB)->delete());
        $this->assertSame(0, DB::table('scan_logs')->where('id', $logB)->delete());
        $this->assertSame(0, DB::table('event_policy_chunks')->where('id', $chunkB)->delete());

        foreach ([
            fn () => DB::table('events')->insert([
                'id' => (string) Str::uuid(),
                'tenant_id' => $tenantB,
                'title' => 'leak',
                'status' => 'DRAFT',
                'created_at' => now(),
            ]),
            fn () => DB::table('sectors')->insert([
                'id' => (string) Str::uuid(),
                'tenant_id' => $tenantB,
                'event_id' => $eventB,
                'name' => 'leak',
                'is_locked' => false,
                'created_at' => now(),
            ]),
            fn () => DB::table('seats')->insert([
                'id' => (string) Str::uuid(),
                'tenant_id' => $tenantB,
                'sector_id' => $seatB['sector_id'],
                'seat_number' => 'LEAK',
                'status' => 'AVAILABLE',
                'created_at' => now(),
            ]),
            fn () => DB::statement(
                'INSERT INTO tickets (id, tenant_id, seat_id, user_id, status, totp_seed, signature, created_at)
                 VALUES (?, ?, ?, ?, ?, decode(?, \'hex\'), ?, ?)',
                [
                    (string) Str::uuid(),
                    $tenantB,
                    $seatB['seat_id'],
                    (string) Str::uuid(),
                    'SOLD',
                    bin2hex(random_bytes(20)),
                    'x',
                    now(),
                ]
            ),
            fn () => DB::table('scan_logs')->insert([
                'id' => (string) Str::uuid(),
                'tenant_id' => $tenantB,
                'ticket_id' => $ticketB,
                'gate_id' => 'G1',
                'result' => 'VALID',
                'scanned_at' => now(),
            ]),
            fn () => DB::statement(
                'INSERT INTO event_policy_chunks (id, tenant_id, event_id, content, embedding, created_at)
                 VALUES (?, ?, ?, ?, ?::vector, ?)',
                [
                    (string) Str::uuid(),
                    $tenantB,
                    $eventB,
                    'leak',
                    '['.implode(',', array_fill(0, 1536, '0')).']',
                    now(),
                ]
            ),
        ] as $attempt) {
            try {
                $attempt();
                $this->fail('R4: cross-tenant INSERT must fail WITH CHECK');
            } catch (QueryException) {
                $this->assertTrue(true);
            }
        }

        DB::rollBack();
        TenantContext::resetRole();
    }

    public function test_r4_superuser_sees_all_but_app_role_is_isolated(): void
    {
        $tenantA = $this->insertTenant('A');
        $tenantB = $this->insertTenant('B');
        $this->insertEvent($tenantA, 'A');
        $this->insertEvent($tenantB, 'B');

        // Default connection (often table owner / superuser): RLS does not apply.
        $this->assertSame(2, DB::table('events')->count(), 'R4 residual: owner/superuser bypasses FORCE RLS');

        $this->beginAppRoleTransaction();
        TenantContext::set($tenantA);
        $this->assertSame(1, DB::table('events')->count(), 'R4: tazkerah_app + GUC isolates to one tenant');
        DB::rollBack();
        TenantContext::resetRole();
    }

    public function test_r4_eloquent_without_global_scope_still_rls_under_app_role(): void
    {
        $tenantA = $this->insertTenant('A');
        $tenantB = $this->insertTenant('B');
        $eventA = $this->insertEvent($tenantA, 'A');
        $eventB = $this->insertEvent($tenantB, 'B');

        $this->beginAppRoleTransaction();
        TenantContext::set($tenantA);

        $ids = Event::withoutGlobalScope('tenant')->pluck('id')->all();
        $this->assertContains($eventA, $ids);
        $this->assertNotContains($eventB, $ids, 'R4: bypassing Eloquent scope must still be blocked by PostgreSQL RLS');

        DB::rollBack();
        TenantContext::resetRole();
    }

    public function test_r4_invalid_guc_uuid_fail_closed(): void
    {
        $tenant = $this->insertTenant('A');
        $this->insertEvent($tenant, 'A');

        $this->beginAppRoleTransaction();
        DB::select("select set_config('app.current_tenant_id', 'not-a-uuid', true)");

        try {
            DB::table('events')->count();
            $this->fail('R4: invalid GUC UUID should error or return no usable rows');
        } catch (QueryException) {
            $this->assertTrue(true);
        }

        DB::rollBack();
        TenantContext::resetRole();
    }

    protected function insertPolicyChunk(string $tenantId, string $eventId): string
    {
        $id = (string) Str::uuid();
        $vector = '['.implode(',', array_fill(0, 1536, '0')).']';

        DB::statement(
            'INSERT INTO event_policy_chunks (id, tenant_id, event_id, content, embedding, created_at)
             VALUES (?, ?, ?, ?, ?::vector, ?)',
            [$id, $tenantId, $eventId, 'policy', $vector, now()]
        );

        return $id;
    }
}
