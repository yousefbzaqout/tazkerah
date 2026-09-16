<?php

namespace Tests\Feature;

use App\Support\TenantContext;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Concerns\InteractsWithTenantRls;
use Tests\TestCase;

/**
 * F-001 / FR-016: AC-016-01, AC-016-02
 */
class TenantRlsIsolationTest extends TestCase
{
    use InteractsWithTenantRls;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->skipUnlessPgsql();
    }

    public function test_ac_016_01_empty_tenant_context_returns_no_rows(): void
    {
        $tenantA = $this->insertTenant('Organizer A');
        $eventA = $this->insertEvent($tenantA, 'A Event');
        $seatBundle = $this->insertSectorAndSeat($tenantA, $eventA);
        $ticketA = $this->insertSoldTicket($tenantA, $seatBundle['seat_id'], (string) Str::uuid());
        $this->insertScanLog($tenantA, $ticketA);

        $this->beginAppRoleTransaction();
        TenantContext::clear();

        $this->assertSame(0, DB::table('events')->count(), 'AC-016-01: events empty without tenant context');
        $this->assertSame(0, DB::table('seats')->count(), 'AC-016-01: seats empty without tenant context');
        $this->assertSame(0, DB::table('scan_logs')->count(), 'AC-016-01: scan_logs empty without tenant context');

        DB::rollBack();
        TenantContext::resetRole();
    }

    public function test_ac_016_02_organizer_a_cannot_see_organizer_b_events_seats_or_scan_logs(): void
    {
        $tenantA = $this->insertTenant('Organizer A');
        $tenantB = $this->insertTenant('Organizer B');

        $eventA = $this->insertEvent($tenantA, 'A Event');
        $eventB = $this->insertEvent($tenantB, 'B Event');

        $seatA = $this->insertSectorAndSeat($tenantA, $eventA, 'A-12');
        $seatB = $this->insertSectorAndSeat($tenantB, $eventB, 'B-12');

        $userA = (string) Str::uuid();
        $userB = (string) Str::uuid();
        $ticketA = $this->insertSoldTicket($tenantA, $seatA['seat_id'], $userA);
        $ticketB = $this->insertSoldTicket($tenantB, $seatB['seat_id'], $userB);

        $logA = $this->insertScanLog($tenantA, $ticketA, 'GATE-A');
        $logB = $this->insertScanLog($tenantB, $ticketB, 'GATE-B');

        $this->beginAppRoleTransaction();
        TenantContext::set($tenantA);

        $events = DB::table('events')->pluck('id')->all();
        $this->assertContains($eventA, $events);
        $this->assertNotContains($eventB, $events, 'AC-016-02: Organizer A must not see Organizer B events');

        $seats = DB::table('seats')->pluck('id')->all();
        $this->assertContains($seatA['seat_id'], $seats);
        $this->assertNotContains($seatB['seat_id'], $seats, 'AC-016-02: Organizer A must not see Organizer B seats');

        $logs = DB::table('scan_logs')->pluck('id')->all();
        $this->assertContains($logA, $logs);
        $this->assertNotContains($logB, $logs, 'AC-016-02: Organizer A must not see Organizer B scan logs');

        $updated = DB::table('events')->where('id', $eventB)->update(['title' => 'Hacked']);
        $this->assertSame(0, $updated, 'AC-016-02: Organizer A must not update Organizer B events');

        DB::rollBack();
        TenantContext::resetRole();
    }
}
