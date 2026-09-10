<?php

namespace Tests\Feature\M0;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class F002DatabaseFoundationTest extends TestCase
{
    use RefreshDatabase;

    public function test_core_application_tables_exist_after_migrations(): void
    {
        $this->assertTrue(Schema::hasTable('users'));
        $this->assertTrue(Schema::hasTable('personal_access_tokens'));
        $this->assertTrue(Schema::hasTable('migrations'));
    }
}
