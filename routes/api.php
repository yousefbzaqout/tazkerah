<?php

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => response()->json(['status' => 'ok']));

Route::middleware('auth:sanctum')->get('/user', function (Request $request) {
    return $request->user();
});

Route::post('/tokens', function (Request $request) {
    $request->validate([
        'email' => ['required', 'email'],
        'password' => ['required'],
        'device_name' => ['required', 'string'],
    ]);

    $user = User::query()->where('email', $request->string('email'))->first();

    if ($user === null || ! \Illuminate\Support\Facades\Hash::check($request->string('password'), $user->password)) {
        return response()->json(['message' => 'Invalid credentials.'], 401);
    }

    return response()->json([
        'token' => $user->createToken($request->string('device_name'))->plainTextToken,
    ]);
});
