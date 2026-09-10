<?php

namespace Tests\Feature\M0;

use PHPUnit\Framework\Attributes\Group;
use Tests\TestCase;

#[Group('pgbouncer')]
class F003PgBouncerFoundationTest extends TestCase
{
    public function test_pgbouncer_service_is_not_yet_configured(): void
    {
        $this->markTestSkipped('F-003 blocked: PgBouncer service is not defined in compose.yaml yet.');
    }
}
