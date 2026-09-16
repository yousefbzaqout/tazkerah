<?php

namespace Tests\Feature;

use App\Auth\LoginOtpVerifier;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\InteractsWithTenantRls;
use Tests\TestCase;

/**
 * F-004 / FR-016 — Sanctum auth + per-request tenant GUC middleware.
 */
class AuthTenantContextTest extends TestCase
{
    use InteractsWithTenantRls;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->skipUnlessPgsql();
    }

    public function test_ac_016_01_missing_tenant_context_returns_empty_events(): void
    {
        $tenant = $this->insertTenant('A');
        $this->insertEvent($tenant, 'Hidden');

        $user = User::factory()->create(['tenant_id' => null]);
        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withToken($token)->getJson('/api/v1/tenant/context');

        $response->assertOk();
        $response->assertJsonPath('db_tenant_id', null);
        $response->assertJsonPath('event_ids', []);
    }

    public function test_member_tenant_binds_guc_and_scopes_events(): void
    {
        $tenantA = $this->insertTenant('A');
        $tenantB = $this->insertTenant('B');
        $eventA = $this->insertEvent($tenantA, 'A');
        $this->insertEvent($tenantB, 'B');

        $user = User::factory()->create(['tenant_id' => $tenantA]);
        $token = $user->createToken('test', ["tenant:{$tenantA}"])->plainTextToken;

        $response = $this->withToken($token)
            ->withHeader('X-Tenant-ID', $tenantA)
            ->getJson('/api/v1/tenant/context');

        $response->assertOk();
        $response->assertJsonPath('db_tenant_id', $tenantA);
        $response->assertJsonPath('event_ids', [$eventA]);
    }

    public function test_x_tenant_id_mismatch_returns_403_problem(): void
    {
        $tenantA = $this->insertTenant('A');
        $tenantB = $this->insertTenant('B');

        $user = User::factory()->create(['tenant_id' => $tenantA]);
        $token = $user->createToken('test', ["tenant:{$tenantA}"])->plainTextToken;

        $response = $this->withToken($token)
            ->withHeader('X-Tenant-ID', $tenantB)
            ->getJson('/api/v1/tenant/context');

        $response->assertForbidden();
        $response->assertJsonPath('status', 403);
        $response->assertJsonPath('type', 'https://tazkerah.com/errors/tenant-mismatch');
    }

    public function test_missing_bearer_returns_401_problem(): void
    {
        $response = $this->getJson('/api/v1/auth/me');

        $response->assertUnauthorized();
        $response->assertJsonPath('status', 401);
        $response->assertJsonPath('type', 'https://tazkerah.com/errors/unauthenticated');
    }

    public function test_login_validation_returns_422_problem(): void
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'identifier' => 'sami@example.com',
            'otp' => '12',
            'client' => 'not_a_client',
        ]);

        $response->assertStatus(422);
        $response->assertJsonPath('status', 422);
        $response->assertJsonPath('type', 'https://tazkerah.com/errors/validation');
    }

    public function test_login_logout_me_contract(): void
    {
        $tenantId = $this->insertTenant('Neon Arena');
        $user = User::factory()->create([
            'name' => 'Sami',
            'email' => 'sami@example.com',
            'tenant_id' => $tenantId,
        ]);

        app(LoginOtpVerifier::class)->store('sami@example.com', '482910');

        $login = $this->postJson('/api/v1/auth/login', [
            'identifier' => 'sami@example.com',
            'otp' => '482910',
            'client' => 'next_web',
        ]);

        $login->assertOk();
        $login->assertJsonPath('token_type', 'Bearer');
        $login->assertJsonPath('user.display_name', 'Sami');
        $login->assertJsonPath('user.roles', ['attendee']);
        $login->assertJsonPath('tenants.0.id', $tenantId);
        $login->assertJsonPath('tenants.0.name', 'Neon Arena');
        $this->assertNotEmpty($login->json('token'));

        $token = $login->json('token');

        $me = $this->withToken($token)->getJson('/api/v1/auth/me');
        $me->assertOk();
        $me->assertJsonPath('email', 'sami@example.com');
        $me->assertJsonPath('name', 'Sami');
        $me->assertJsonPath('tenants.0.id', $tenantId);
        $me->assertJsonPath('tenants.0.roles', ['attendee']);

        $logout = $this->withToken($token)->postJson('/api/v1/auth/logout');
        $logout->assertNoContent();

        $after = $this->withToken($token)->getJson('/api/v1/auth/me');
        $after->assertUnauthorized();
    }

    public function test_invalid_otp_returns_401(): void
    {
        User::factory()->create(['email' => 'sami@example.com']);
        app(LoginOtpVerifier::class)->store('sami@example.com', '111111');

        $response = $this->postJson('/api/v1/auth/login', [
            'identifier' => 'sami@example.com',
            'otp' => '999999',
            'client' => 'next_web',
        ]);

        $response->assertUnauthorized();
        $response->assertJsonPath('type', 'https://tazkerah.com/errors/invalid-otp');
    }

    public function test_concurrent_requests_do_not_bleed_tenant_context(): void
    {
        $tenantA = $this->insertTenant('A');
        $tenantB = $this->insertTenant('B');
        $eventA = $this->insertEvent($tenantA, 'A');
        $eventB = $this->insertEvent($tenantB, 'B');

        $userA = User::factory()->create(['tenant_id' => $tenantA]);
        $userB = User::factory()->create(['tenant_id' => $tenantB]);
        $tokenA = $userA->createToken('a', ["tenant:{$tenantA}"])->plainTextToken;
        $tokenB = $userB->createToken('b', ["tenant:{$tenantB}"])->plainTextToken;

        $responseA = $this->withToken($tokenA)
            ->withHeader('X-Tenant-ID', $tenantA)
            ->getJson('/api/v1/tenant/context');
        $responseB = $this->withToken($tokenB)
            ->withHeader('X-Tenant-ID', $tenantB)
            ->getJson('/api/v1/tenant/context');

        $responseA->assertOk()->assertJsonPath('db_tenant_id', $tenantA)->assertJsonPath('event_ids', [$eventA]);
        $responseB->assertOk()->assertJsonPath('db_tenant_id', $tenantB)->assertJsonPath('event_ids', [$eventB]);

        // Alternate again to catch sticky session GUC bleed on the same connection.
        $againA = $this->withToken($tokenA)
            ->withHeader('X-Tenant-ID', $tenantA)
            ->getJson('/api/v1/tenant/context');
        $againA->assertOk()->assertJsonPath('event_ids', [$eventA]);
    }
}
