<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

final class TenantContext
{
    public const GUC = 'app.current_tenant_id';

    public static function set(?string $tenantId): void
    {
        if ($tenantId === null || $tenantId === '') {
            self::clear();

            return;
        }

        // SET LOCAL equivalent via set_config(..., is_local = true) on the direct PostgreSQL session.
        DB::select('select set_config(?, ?, true) as v', [self::GUC, $tenantId]);
    }

    public static function clear(): void
    {
        DB::select('select set_config(?, ?, true) as v', [self::GUC, '']);
    }

    public static function current(): ?string
    {
        $value = DB::selectOne(
            "select nullif(current_setting(?, true), '') as tenant_id",
            [self::GUC]
        );

        return $value?->tenant_id ?: null;
    }

    public static function useAppRole(): void
    {
        if (Schema::getConnection()->getDriverName() !== 'pgsql') {
            return;
        }

        // Non-superuser role so FORCE RLS applies during app queries / tests.
        DB::statement('SET ROLE tazkerah_app');
    }

    public static function resetRole(): void
    {
        if (Schema::getConnection()->getDriverName() !== 'pgsql') {
            return;
        }

        DB::statement('RESET ROLE');
    }
}
