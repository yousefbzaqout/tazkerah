<?php

namespace App\Auth;

/**
 * Maps docs/14 X-Client / login client values to role labels for token abilities + /auth/me.
 */
final class AuthClientRoles
{
    public const CLIENTS = [
        'next_web',
        'flutter_vault',
        'flutter_gate',
        'organizer_web',
    ];

    /**
     * @return list<string>
     */
    public static function rolesForClient(string $client): array
    {
        return match ($client) {
            'organizer_web' => ['organizer'],
            'flutter_gate' => ['gate_staff'],
            'next_web', 'flutter_vault' => ['attendee'],
            default => [],
        };
    }
}
