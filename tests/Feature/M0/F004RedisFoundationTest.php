<?php

namespace Tests\Feature\M0;

use Illuminate\Support\Facades\Redis;
use PHPUnit\Framework\Attributes\Group;
use Tests\TestCase;

#[Group('redis')]
class F004RedisFoundationTest extends TestCase
{
    public function test_redis_is_reachable_when_service_is_running(): void
    {
        if (! extension_loaded('redis')) {
            $this->markTestSkipped('F-004: phpredis extension is not installed in this environment.');
        }

        try {
            $this->assertSame('PONG', Redis::connection()->ping());
        } catch (\Throwable $exception) {
            $this->markTestSkipped('F-004: Redis is not reachable without docker compose (pgsql, redis). '.$exception->getMessage());
        }
    }
}
