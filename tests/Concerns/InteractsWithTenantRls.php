<?php

namespace Tests\Concerns;

use App\Support\TenantContext;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

trait InteractsWithTenantRls
{
    protected function skipUnlessPgsql(): void
    {
        if (Schema::getConnection()->getDriverName() !== 'pgsql') {
            $this->markTestSkipped('F-001 RLS tests require PostgreSQL.');
        }
    }

    protected function beginAppRoleTransaction(): void
    {
        DB::beginTransaction();
        TenantContext::useAppRole();
    }

    protected function insertTenant(string $name = 'Tenant'): string
    {
        $id = (string) Str::uuid();
        DB::table('tenants')->insert([
            'id' => $id,
            'name' => $name,
            'created_at' => now(),
        ]);

        return $id;
    }

    protected function insertEvent(string $tenantId, string $title = 'Event'): string
    {
        $id = (string) Str::uuid();
        DB::table('events')->insert([
            'id' => $id,
            'tenant_id' => $tenantId,
            'title' => $title,
            'status' => 'DRAFT',
            'created_at' => now(),
        ]);

        return $id;
    }

    /**
     * @return array{sector_id: string, seat_id: string}
     */
    protected function insertSectorAndSeat(string $tenantId, string $eventId, string $seatNumber = 'A-1'): array
    {
        $sectorId = (string) Str::uuid();
        DB::table('sectors')->insert([
            'id' => $sectorId,
            'tenant_id' => $tenantId,
            'event_id' => $eventId,
            'name' => 'VIP',
            'is_locked' => false,
            'created_at' => now(),
        ]);

        $seatId = (string) Str::uuid();
        DB::table('seats')->insert([
            'id' => $seatId,
            'tenant_id' => $tenantId,
            'sector_id' => $sectorId,
            'seat_number' => $seatNumber,
            'status' => 'AVAILABLE',
            'created_at' => now(),
        ]);

        return ['sector_id' => $sectorId, 'seat_id' => $seatId];
    }

    /**
     * Ticket row only valid at SOLD per lifecycle SoT (BR-007).
     */
    protected function insertSoldTicket(string $tenantId, string $seatId, string $userId): string
    {
        $id = (string) Str::uuid();
        $seedHex = bin2hex(random_bytes(20));

        DB::statement(
            'INSERT INTO tickets (id, tenant_id, seat_id, user_id, status, totp_seed, signature, created_at)
             VALUES (?, ?, ?, ?, ?, decode(?, \'hex\'), ?, ?)',
            [
                $id,
                $tenantId,
                $seatId,
                $userId,
                'SOLD',
                $seedHex,
                'test-signature',
                now(),
            ]
        );

        return $id;
    }

    protected function insertScanLog(string $tenantId, string $ticketId, string $gateId = 'GATE-01'): string
    {
        $id = (string) Str::uuid();
        DB::table('scan_logs')->insert([
            'id' => $id,
            'tenant_id' => $tenantId,
            'ticket_id' => $ticketId,
            'gate_id' => $gateId,
            'result' => 'VALID',
            'scanned_at' => now(),
        ]);

        return $id;
    }
}
