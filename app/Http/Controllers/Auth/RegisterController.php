<?php

namespace Pterodactyl\Http\Controllers\Auth;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rules\Password;
use Pterodactyl\Services\Users\UserCreationService;

class RegisterController extends AbstractLoginController
{
    public function __construct(private UserCreationService $creationService)
    {
        parent::__construct();
    }

    public function register(Request $request): JsonResponse
    {
        if (!config('auth.registration.enabled')) {
            abort(404);
        }

        $validated = $request->validate([
            'username' => ['required', 'string', 'between:1,191', 'unique:users,username', new \Pterodactyl\Rules\Username()],
            'email' => ['required', 'email:strict', 'between:1,191', 'unique:users,email'],
            'name_first' => ['required', 'string', 'between:1,191'],
            'name_last' => ['required', 'string', 'between:1,191'],
            'password' => ['required', 'confirmed', Password::min(12)->mixedCase()->numbers()],
        ]);

        $user = $this->creationService->handle(array_merge($validated, [
            'root_admin' => false,
            'use_totp' => false,
            'language' => 'en',
        ]));

        return $this->sendLoginResponse($user, $request);
    }
}
