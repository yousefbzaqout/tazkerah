<?php

namespace App\Http\Controllers\Api\V1;

use App\Auth\AuthClientRoles;
use App\Auth\LoginOtpVerifier;
use App\Http\Requests\LoginRequest;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Laravel\Sanctum\PersonalAccessToken;

final class AuthController
{
    public function login(LoginRequest $request, LoginOtpVerifier $otpVerifier): JsonResponse
    {
        $identifier = (string) $request->validated('identifier');
        $otp = (string) $request->validated('otp');
        $client = (string) $request->validated('client');

        if (! $otpVerifier->consume($identifier, $otp)) {
            return response()->json([
                'type' => 'https://tazkerah.com/errors/invalid-otp',
                'title' => 'Unauthorized',
                'status' => 401,
                'detail' => 'Invalid OTP.',
            ], 401);
        }

        $user = User::query()->where('email', $identifier)->first();

        if ($user === null) {
            return response()->json([
                'type' => 'https://tazkerah.com/errors/invalid-otp',
                'title' => 'Unauthorized',
                'status' => 401,
                'detail' => 'Invalid OTP.',
            ], 401);
        }

        $roles = AuthClientRoles::rolesForClient($client);
        $abilities = array_map(static fn (string $role) => 'role:'.$role, $roles);

        if (! empty($user->tenant_id)) {
            $abilities[] = 'tenant:'.(string) $user->tenant_id;
        }

        $expiresAt = now()->addHours(12);
        $newToken = $user->createToken($client, $abilities, $expiresAt);

        return response()->json([
            'token' => $newToken->plainTextToken,
            'token_type' => 'Bearer',
            'expires_at' => $expiresAt->toIso8601String(),
            'user' => [
                'id' => (string) $user->id,
                'display_name' => $user->name,
                'roles' => $roles,
            ],
            'tenants' => $this->tenantSummaries($user, $roles),
        ]);
    }

    public function logout(Request $request): Response|JsonResponse
    {
        $user = $request->user();

        if ($user === null) {
            return response()->json([
                'type' => 'https://tazkerah.com/errors/unauthenticated',
                'title' => 'Unauthorized',
                'status' => 401,
                'detail' => 'Missing or invalid Bearer token.',
            ], 401);
        }

        $token = $user->currentAccessToken();
        if ($token instanceof PersonalAccessToken) {
            $token->delete();
        }

        return response()->noContent();
    }

    public function me(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user === null) {
            return response()->json([
                'type' => 'https://tazkerah.com/errors/unauthenticated',
                'title' => 'Unauthorized',
                'status' => 401,
                'detail' => 'Missing or invalid Bearer token.',
            ], 401);
        }

        $roles = $this->rolesFromToken($user);

        return response()->json([
            'user_id' => (string) $user->id,
            'email' => $user->email,
            'name' => $user->name,
            'tenants' => $this->tenantSummaries($user, $roles),
        ]);
    }

    /**
     * @param  list<string>  $roles
     * @return list<array{id: string, name: string, roles?: list<string>}>
     */
    private function tenantSummaries(User $user, array $roles): array
    {
        if (empty($user->tenant_id)) {
            return [];
        }

        $tenant = Tenant::query()->find($user->tenant_id);
        if ($tenant === null) {
            return [];
        }

        return [[
            'id' => (string) $tenant->id,
            'name' => $tenant->name,
            'roles' => $roles,
        ]];
    }

    /**
     * @return list<string>
     */
    private function rolesFromToken(User $user): array
    {
        $token = $user->currentAccessToken();
        if ($token === null) {
            return [];
        }

        $roles = [];
        foreach ($token->abilities ?? [] as $ability) {
            if (is_string($ability) && str_starts_with($ability, 'role:')) {
                $roles[] = substr($ability, strlen('role:'));
            }
        }

        return $roles;
    }
}
