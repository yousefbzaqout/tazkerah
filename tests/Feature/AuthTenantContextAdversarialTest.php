<?php

namespace Tests\Feature;

use App\Auth\LoginOtpVerifier;
use App\Models\Event;
use App\Models\User;
use App\Support\TenantContext;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Concerns\InteractsWithTenantRls;
use Tests\TestCase;

/**
 * R4 / FR-016 deep adversarial suite for F-004 auth + tenant GUC binding.
 */
class AuthTenantContextAdversarialTest extends TestCase
{
    use InteractsWithTenantRls;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->skipUnlessPgsql();
    }

    public function test_r4_header_without_membership_forbidden(): void
    {
        $tenant = $this->insertTenant('Foreign');
        $this->insertEvent($tenant, 'Secret');

        $user = User::factory()->create(['tenant_id' => null, 'roles' => ['attendee']]);
        $token = $user->createToken('t')->plainTextToken;

        $response = $this->withToken($token)
            ->withHeader('X-Tenant-ID', $tenant)
            ->getJson('/api/v1/tenant/context');

        $response->assertForbidden();
        $response->assertJsonPath('type', 'https://tazkerah.com/errors/tenant-forbidden');
    }

    public function test_r4_forged_tenant_ability_cannot_override_membership(): void
    {
        $tenantA = $this->insertTenant('A');
        $tenantB = $this->insertTenant('B');
        $this->insertEvent($tenantA, 'A');
        $this->insertEvent($tenantB, 'B');

        // Membership is A, but token ability claims B — reject (stale/forged ability).
        $user = User::factory()->create(['tenant_id' => $tenantA, 'roles' => ['attendee']]);
        $token = $user->createToken('evil', ["tenant:{$tenantB}"])->plainTextToken;

        $this->flushHeaders();
        $mismatch = $this->withToken($token)
            ->withHeader('X-Tenant-ID', $tenantA)
            ->getJson('/api/v1/tenant/context');
        $mismatch->assertForbidden();
        $mismatch->assertJsonPath('type', 'https://tazkerah.com/errors/tenant-mismatch');

        $headerB = $this->withToken($token)
            ->withHeader('X-Tenant-ID', $tenantB)
            ->getJson('/api/v1/tenant/context');
        $headerB->assertForbidden();
    }

    public function test_r4_malformed_x_tenant_id_ignored_not_bound(): void
    {
        $tenantA = $this->insertTenant('A');
        $eventA = $this->insertEvent($tenantA, 'A');

        $user = User::factory()->create(['tenant_id' => $tenantA]);
        $token = $user->createToken('t', ["tenant:{$tenantA}"])->plainTextToken;

        $response = $this->withToken($token)
            ->withHeader('X-Tenant-ID', 'not-a-uuid')
            ->getJson('/api/v1/tenant/context');

        // Malformed header is ignored; membership still binds.
        $response->assertOk();
        $response->assertJsonPath('db_tenant_id', $tenantA);
        $response->assertJsonPath('event_ids', [$eventA]);
    }

    public function test_r4_otp_is_single_use(): void
    {
        User::factory()->create([
            'email' => 'once@example.com',
            'roles' => ['attendee'],
        ]);
        app(LoginOtpVerifier::class)->store('once@example.com', '123456');

        $first = $this->postJson('/api/v1/auth/login', [
            'identifier' => 'once@example.com',
            'otp' => '123456',
            'client' => 'next_web',
        ]);
        $first->assertOk();

        $second = $this->postJson('/api/v1/auth/login', [
            'identifier' => 'once@example.com',
            'otp' => '123456',
            'client' => 'next_web',
        ]);
        $second->assertUnauthorized();
        $second->assertJsonPath('type', 'https://tazkerah.com/errors/invalid-otp');
    }

    public function test_r4_attendee_cannot_escalate_via_flutter_gate_client(): void
    {
        User::factory()->create([
            'email' => 'gate-try@example.com',
            'roles' => ['attendee'],
        ]);
        app(LoginOtpVerifier::class)->store('gate-try@example.com', '654321');

        $response = $this->postJson('/api/v1/auth/login', [
            'identifier' => 'gate-try@example.com',
            'otp' => '654321',
            'client' => 'flutter_gate',
        ]);

        $response->assertForbidden();
        $response->assertJsonPath('type', 'https://tazkerah.com/errors/client-forbidden');
    }

    public function test_r4_logout_does_not_revoke_other_tokens(): void
    {
        $user = User::factory()->create(['roles' => ['attendee']]);
        $tokenKeep = $user->createToken('keep')->plainTextToken;
        $tokenDrop = $user->createToken('drop')->plainTextToken;

        $this->withToken($tokenDrop)->postJson('/api/v1/auth/logout')->assertNoContent();

        $this->withToken($tokenDrop)->getJson('/api/v1/auth/me')->assertUnauthorized();
        $this->withToken($tokenKeep)->getJson('/api/v1/auth/me')->assertOk();
    }

    public function test_r4_guc_cleared_after_request_no_sticky_bleed(): void
    {
        $tenantA = $this->insertTenant('A');
        $tenantB = $this->insertTenant('B');
        $eventA = $this->insertEvent($tenantA, 'A');
        $eventB = $this->insertEvent($tenantB, 'B');

        $userA = User::factory()->create(['tenant_id' => $tenantA]);
        $userB = User::factory()->create(['tenant_id' => $tenantB]);
        $tokenA = $userA->createToken('a', ["tenant:{$tenantA}"])->plainTextToken;
        $tokenB = $userB->createToken('b', ["tenant:{$tenantB}"])->plainTextToken;

        for ($i = 0; $i < 5; $i++) {
            $this->withToken($tokenA)->withHeader('X-Tenant-ID', $tenantA)
                ->getJson('/api/v1/tenant/context')
                ->assertOk()
                ->assertJsonPath('event_ids', [$eventA]);

            $this->withToken($tokenB)->withHeader('X-Tenant-ID', $tenantB)
                ->getJson('/api/v1/tenant/context')
                ->assertOk()
                ->assertJsonPath('event_ids', [$eventB]);
        }

        // After alternating authenticated calls, principal without membership sees empty (no sticky X-Tenant-ID).
        $lonely = User::factory()->create(['tenant_id' => null]);
        $lonelyToken = $lonely->createToken('lonely')->plainTextToken;
        $this->flushHeaders();
        $this->withToken($lonelyToken)->getJson('/api/v1/tenant/context')
            ->assertOk()
            ->assertJsonPath('db_tenant_id', null)
            ->assertJsonPath('event_ids', []);
    }

    public function test_r4_login_throttle_returns_429(): void
    {
        User::factory()->create([
            'email' => 'throttle@example.com',
            'roles' => ['attendee'],
        ]);

        $last = null;
        for ($i = 0; $i < 12; $i++) {
            $last = $this->postJson('/api/v1/auth/login', [
                'identifier' => 'throttle@example.com',
                'otp' => '000000',
                'client' => 'next_web',
            ]);
        }

        $this->assertNotNull($last);
        $last->assertStatus(429);
    }

    public function test_r4_without_global_scope_still_rls_under_app_role_via_http(): void
    {
        $tenantA = $this->insertTenant('A');
        $tenantB = $this->insertTenant('B');
        $eventA = $this->insertEvent($tenantA, 'A');
        $eventB = $this->insertEvent($tenantB, 'B');

        $user = User::factory()->create(['tenant_id' => $tenantA]);
        $token = $user->createToken('t', ["tenant:{$tenantA}"])->plainTextToken;

        // Probe route uses Event::query() (scoped). Direct withoutGlobalScope under HTTP path
        // is covered by asserting only eventA is visible; RLS backstop verified in F-001 suite.
        $response = $this->withToken($token)
            ->withHeader('X-Tenant-ID', $tenantA)
            ->getJson('/api/v1/tenant/context');

        $response->assertOk();
        $ids = $response->json('event_ids');
        $this->assertSame([$eventA], $ids);
        $this->assertNotContains($eventB, $ids);

        // Explicit RLS backstop under app role (same connection pattern as middleware).
        DB::beginTransaction();
        TenantContext::useAppRole();
        TenantContext::set($tenantA);
        $raw = Event::withoutGlobalScope('tenant')->pluck('id')->all();
        $this->assertContains($eventA, $raw);
        $this->assertNotContains($eventB, $raw);
        DB::rollBack();
        TenantContext::resetRole();
    }

    public function test_r4_cleared_membership_ignores_stale_tenant_ability(): void
    {
        $tenantA = $this->insertTenant('A');
        $this->insertEvent($tenantA, 'A');

        $user = User::factory()->create([
            'tenant_id' => $tenantA,
            'roles' => ['attendee'],
        ]);
        $token = $user->createToken('stale', ["tenant:{$tenantA}"])->plainTextToken;

        // Membership revoked after issuance.
        $user->forceFill(['tenant_id' => null])->save();

        $this->flushHeaders();
        $response = $this->withToken($token)->getJson('/api/v1/tenant/context');

        $response->assertOk();
        $response->assertJsonPath('db_tenant_id', null);
        $response->assertJsonPath('event_ids', []);
    }

    public function test_r4_unknown_user_invalid_otp_does_not_leak(): void
    {
        app(LoginOtpVerifier::class)->store('ghost@example.com', '111111');

        $response = $this->postJson('/api/v1/auth/login', [
            'identifier' => 'ghost@example.com',
            'otp' => '111111',
            'client' => 'next_web',
        ]);

        // User missing → same 401 invalid-otp surface (no user enumeration via distinct type).
        $response->assertUnauthorized();
        $response->assertJsonPath('type', 'https://tazkerah.com/errors/invalid-otp');
    }
}
