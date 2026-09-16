<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('personal_access_tokens', function (Blueprint $table) {
            $table->id();
            $table->morphs('tokenable');
            $table->text('name');
            $table->string('token', 64)->unique();
            $table->text('abilities')->nullable();
            $table->timestamp('last_used_at')->nullable();
            $table->timestamp('expires_at')->nullable()->index();
            $table->timestamps();
        });

        // Ensure app role can mint Sanctum tokens after SET ROLE tazkerah_app (F-004).
        if (Schema::getConnection()->getDriverName() === 'pgsql') {
            DB::statement('GRANT SELECT, INSERT, UPDATE, DELETE ON personal_access_tokens TO tazkerah_app');
            DB::statement('GRANT USAGE, SELECT ON SEQUENCE personal_access_tokens_id_seq TO tazkerah_app');
            DB::statement('GRANT SELECT, INSERT, UPDATE, DELETE ON users TO tazkerah_app');
            DB::statement('GRANT SELECT ON tenants TO tazkerah_app');
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('personal_access_tokens');
    }
};
