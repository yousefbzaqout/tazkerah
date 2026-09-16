<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Models\Event;
use App\Support\TenantContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:10,1');

    Route::middleware('auth:sanctum')->group(function (): void {
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/auth/me', [AuthController::class, 'me']);

        // Probe for F-004 AC-016-01 / concurrent isolation (not a public product route).
        Route::get('/tenant/context', function (Request $request) {
            return response()->json([
                'tenant_id' => $request->user()?->tenant_id,
                'db_tenant_id' => TenantContext::current(),
                'event_ids' => Event::query()->orderBy('id')->pluck('id'),
            ]);
        });
    });
});
