<?php

namespace App\Auth;

use Illuminate\Contracts\Cache\LockTimeoutException;
use Illuminate\Support\Facades\Cache;

/**
 * Phase-1 OTP verifier for F-004 login (docs/14 §1.1).
 * Issuance/delivery is out of F-004 (T-NEXT-01 / T-AUTH-* UI). Tests seed cache challenges.
 */
final class LoginOtpVerifier
{
    public static function cacheKey(string $identifier): string
    {
        return 'auth:otp:'.hash('sha256', strtolower(trim($identifier)));
    }

    public function store(string $identifier, string $otp, int $ttlSeconds = 300): void
    {
        Cache::put(self::cacheKey($identifier), $otp, $ttlSeconds);
    }

    public function consume(string $identifier, string $otp): bool
    {
        $key = self::cacheKey($identifier);

        try {
            return (bool) Cache::lock($key.':lock', 5)->block(3, function () use ($key, $otp) {
                return $this->consumeUnlocked($key, $otp);
            });
        } catch (LockTimeoutException) {
            return false;
        } catch (\Throwable) {
            // Drivers without lock support (rare): fall back to unlocked consume.
            return $this->consumeUnlocked($key, $otp);
        }
    }

    private function consumeUnlocked(string $key, string $otp): bool
    {
        $expected = Cache::get($key);

        if (! is_string($expected) || $expected === '' || ! hash_equals($expected, $otp)) {
            return false;
        }

        Cache::forget($key);

        return true;
    }
}
