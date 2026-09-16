<?php

namespace App\Http\Requests;

use App\Auth\AuthClientRoles;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;

class LoginRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'identifier' => ['required', 'string', 'max:255'],
            'otp' => ['required', 'string', 'size:6'],
            'client' => ['required', 'string', 'in:'.implode(',', AuthClientRoles::CLIENTS)],
        ];
    }

    protected function failedValidation(Validator $validator): void
    {
        throw new HttpResponseException(response()->json([
            'type' => 'https://tazkerah.com/errors/validation',
            'title' => 'Unprocessable Entity',
            'status' => 422,
            'detail' => 'Validation failed.',
            'errors' => $validator->errors(),
        ], 422));
    }
}
