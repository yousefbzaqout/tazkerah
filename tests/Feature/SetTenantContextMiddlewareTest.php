<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * Legacy F-004 probe — superseded by AuthTenantContextTest; kept for header binding smoke.
 */
class SetTenantContextMiddlewareTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        if (Schema::getConnection()->getDriverName() !== 'pgsql') {
            $this->markTestSkipped('F-004 tenant middleware tests require PostgreSQL.');
        }
    }

    public function test_user_tenant_id_sets_database_guc(): void
    {
        $tenantId = (string) Str::uuid();
        DB::table('tenants')->insert([
            'id' => $tenantId,
            'name' => 'User Tenant',
            'created_at' => now(),
        ]);

        $user = User::factory()->create(['tenant_id' => $tenantId]);
        $token = $user->createToken('test', ["tenant:{$tenantId}"])->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/tenant/context');

        $response->assertOk();
        $response->assertJsonPath('db_tenant_id', $tenantId);
        $response->assertJsonPath('tenant_id', $tenantId);
    }
}
