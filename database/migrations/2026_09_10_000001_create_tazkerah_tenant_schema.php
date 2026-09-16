<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * F-001: Multi-tenant schema + PostgreSQL RLS (Architecture §5, ADR-002, FR-016).
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::getConnection()->getDriverName() !== 'pgsql') {
            throw new RuntimeException('F-001 requires PostgreSQL (RLS).');
        }

        DB::statement('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"');
        DB::statement('CREATE EXTENSION IF NOT EXISTS "vector"');

        Schema::create('tenants', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('uuid_generate_v4()'));
            $table->string('name');
            $table->timestampTz('created_at')->useCurrent();
        });

        Schema::table('users', function (Blueprint $table) {
            $table->uuid('tenant_id')->nullable()->after('id');
            $table->foreign('tenant_id')->references('id')->on('tenants')->nullOnDelete();
        });

        Schema::create('events', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('uuid_generate_v4()'));
            $table->uuid('tenant_id');
            $table->string('title');
            $table->string('status', 50)->default('DRAFT');
            $table->timestampTz('created_at')->useCurrent();
            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->index('tenant_id');
        });

        Schema::create('sectors', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('uuid_generate_v4()'));
            $table->uuid('tenant_id');
            $table->uuid('event_id');
            $table->string('name', 100);
            $table->boolean('is_locked')->default(false);
            $table->timestampTz('created_at')->useCurrent();
            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign('event_id')->references('id')->on('events')->cascadeOnDelete();
            $table->index('tenant_id');
        });

        Schema::create('seats', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('uuid_generate_v4()'));
            $table->uuid('tenant_id');
            $table->uuid('sector_id');
            $table->string('seat_number', 50);
            $table->string('status', 50)->default('AVAILABLE');
            $table->timestampTz('created_at')->useCurrent();
            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign('sector_id')->references('id')->on('sectors')->cascadeOnDelete();
            $table->index('tenant_id');
        });

        Schema::create('tickets', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('uuid_generate_v4()'));
            $table->uuid('tenant_id');
            $table->uuid('seat_id');
            $table->uuid('user_id');
            $table->string('status', 50)->default('SOLD');
            $table->binary('totp_seed');
            $table->text('signature');
            $table->timestampTz('created_at')->useCurrent();
            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign('seat_id')->references('id')->on('seats')->cascadeOnDelete();
            $table->index('tenant_id');
        });

        Schema::create('scan_logs', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('uuid_generate_v4()'));
            $table->uuid('tenant_id');
            $table->uuid('ticket_id');
            $table->string('gate_id', 100);
            $table->string('result', 50);
            $table->timestampTz('scanned_at')->useCurrent();
            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign('ticket_id')->references('id')->on('tickets')->cascadeOnDelete();
            $table->index('tenant_id');
        });

        Schema::create('event_policy_chunks', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('uuid_generate_v4()'));
            $table->uuid('tenant_id');
            $table->uuid('event_id');
            $table->text('content');
            $table->timestampTz('created_at')->useCurrent();
            $table->foreign('tenant_id')->references('id')->on('tenants')->cascadeOnDelete();
            $table->foreign('event_id')->references('id')->on('events')->cascadeOnDelete();
            $table->index('tenant_id');
        });

        DB::statement('ALTER TABLE event_policy_chunks ADD COLUMN embedding vector(1536) NOT NULL');
        DB::statement('CREATE INDEX idx_policy_embeddings ON event_policy_chunks USING hnsw (embedding vector_cosine_ops)');

        foreach (['events', 'sectors', 'seats', 'tickets', 'scan_logs', 'event_policy_chunks'] as $table) {
            DB::statement("ALTER TABLE {$table} ENABLE ROW LEVEL SECURITY");
            DB::statement("ALTER TABLE {$table} FORCE ROW LEVEL SECURITY");
        }

        DB::statement("
            CREATE POLICY tenant_isolation_events ON events
            FOR ALL
            USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid)
        ");
        DB::statement("
            CREATE POLICY tenant_isolation_sectors ON sectors
            FOR ALL
            USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid)
        ");
        DB::statement("
            CREATE POLICY tenant_isolation_seats ON seats
            FOR ALL
            USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid)
        ");
        DB::statement("
            CREATE POLICY tenant_isolation_tickets ON tickets
            FOR ALL
            USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid)
        ");
        DB::statement("
            CREATE POLICY tenant_isolation_scan_logs ON scan_logs
            FOR ALL
            USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid)
        ");
        DB::statement("
            CREATE POLICY tenant_isolation_policy_chunks ON event_policy_chunks
            FOR ALL
            USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid)
            WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::uuid)
        ");

        // App role used by tests / optional DB role for FORCE RLS (superuser bypasses RLS otherwise).
        DB::statement('DO $$ BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = \'tazkerah_app\') THEN
                CREATE ROLE tazkerah_app NOLOGIN;
            END IF;
        END $$');
        DB::statement('GRANT USAGE ON SCHEMA public TO tazkerah_app');
        DB::statement('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO tazkerah_app');
        DB::statement('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO tazkerah_app');
        DB::statement('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO tazkerah_app');
    }

    public function down(): void
    {
        Schema::dropIfExists('event_policy_chunks');
        Schema::dropIfExists('scan_logs');
        Schema::dropIfExists('tickets');
        Schema::dropIfExists('seats');
        Schema::dropIfExists('sectors');
        Schema::dropIfExists('events');

        Schema::table('users', function (Blueprint $table) {
            $table->dropForeign(['tenant_id']);
            $table->dropColumn('tenant_id');
        });

        Schema::dropIfExists('tenants');
    }
};
