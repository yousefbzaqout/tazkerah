<?php

namespace App\Http\Middleware;

use App\Support\TenantContext;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Schema;
use Symfony\Component\HttpFoundation\Response;

/**
 * F-004 / ADR-002: Bind tenant into PostgreSQL GUC for FORCE RLS + Eloquent scopes.
 *
 * Phase-1 (direct PostgreSQL / PHP-FPM): session-scoped GUC cleared in finally (no Octane).
 * Production DB role should be non-bypass (`tazkerah_app`); SET ROLE is applied when pgsql.
 *
 * Resolution order:
 * 1) Authenticated user's tenant_id (authoritative membership)
 * 2) Sanctum ability tenant:{uuid}
 * 3) X-Tenant-ID only when it matches (1) or (2) — never elevates beyond membership
 */
final class SetTenantContext
{
    public function handle(Request $request, Closure $next): Response
    {
        $usedAppRole = false;

        try {
            if ($this->isPgsql()) {
                TenantContext::useAppRole();
                $usedAppRole = true;
            }

            $resolved = $this->resolveTenantId($request);

            if ($resolved['error'] !== null) {
                return $resolved['error'];
            }

            if ($resolved['tenant_id'] !== null) {
                TenantContext::set($resolved['tenant_id'], local: false);
            } else {
                TenantContext::clear(local: false);
            }

            return $next($request);
        } finally {
            TenantContext::clear(local: false);
            if ($usedAppRole) {
                TenantContext::resetRole();
            }
        }
    }

    /**
     * @return array{tenant_id: ?string, error: ?Response}
     */
    private function resolveTenantId(Request $request): array
    {
        $user = $request->user();
        $header = $request->header('X-Tenant-ID');
        $headerTenant = (is_string($header) && $header !== '' && $this->looksLikeUuid($header))
            ? $header
            : null;

        $membershipTenant = null;
        if ($user !== null && ! empty($user->tenant_id)) {
            $membershipTenant = (string) $user->tenant_id;
        }

        $abilityTenant = null;
        if ($user !== null && method_exists($user, 'currentAccessToken')) {
            $token = $user->currentAccessToken();
            if ($token !== null) {
                foreach ($token->abilities ?? [] as $ability) {
                    if (is_string($ability) && str_starts_with($ability, 'tenant:')) {
                        $abilityTenant = substr($ability, strlen('tenant:'));
                        break;
                    }
                }
            }
        }

        $bound = $membershipTenant ?? $abilityTenant;

        if ($headerTenant !== null) {
            if ($bound !== null && ! hash_equals($bound, $headerTenant)) {
                return [
                    'tenant_id' => null,
                    'error' => response()->json([
                        'type' => 'https://tazkerah.com/errors/tenant-mismatch',
                        'title' => 'Forbidden',
                        'status' => 403,
                        'detail' => 'X-Tenant-ID does not match the authenticated membership.',
                    ], 403),
                ];
            }

            if ($bound === null) {
                return [
                    'tenant_id' => null,
                    'error' => response()->json([
                        'type' => 'https://tazkerah.com/errors/tenant-forbidden',
                        'title' => 'Forbidden',
                        'status' => 403,
                        'detail' => 'X-Tenant-ID is not authorized for this principal.',
                    ], 403),
                ];
            }

            return ['tenant_id' => $headerTenant, 'error' => null];
        }

        return ['tenant_id' => $bound, 'error' => null];
    }

    private function looksLikeUuid(string $value): bool
    {
        return (bool) preg_match(
            '/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i',
            $value
        );
    }

    private function isPgsql(): bool
    {
        return Schema::getConnection()->getDriverName() === 'pgsql';
    }

    /**
     * Drop cached guard users so the next HTTP cycle re-resolves Sanctum tokens.
     * (PHPUnit reuses the app container; PHP-FPM does not need this but it is harmless.)
     */
    public function terminate(Request $request, Response $response): void
    {
        Auth::forgetGuards();
    }
}
