<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

final class TenantContext
{
    public const GUC = 'app.current_tenant_id';

    /**
     * @param  bool  $local  true = SET LOCAL (requires open transaction); false = session GUC (PHP-FPM request + finally clear)
     */
    public static function set(?string $tenantId, bool $local = true): void
    {
        if ($tenantId === null || $tenantId === '') {
            self::clear($local);

            return;
        }

        // SET LOCAL when $local=true (requires open transaction); session GUC otherwise.
        DB::select(
            'select set_config(?, ?, '.($local ? 'true' : 'false').') as v',
            [self::GUC, $tenantId]
        );
    }

    public static function clear(bool $local = true): void
    {
        try {
            DB::select(
                'select set_config(?, ?, '.($local ? 'true' : 'false').') as v',
                [self::GUC, '']
            );
        } catch (\Throwable) {
            // Avoid masking the original request exception when the connection is already aborted.
        }
    }

    public static function current(): ?string
    {
        try {
            $value = DB::selectOne(
                "select nullif(current_setting(?, true), '') as tenant_id",
                [self::GUC]
            );
        } catch (\Throwable) {
            return null;
        }

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

        try {
            DB::statement('RESET ROLE');
        } catch (\Throwable) {
            //
        }
    }
}
