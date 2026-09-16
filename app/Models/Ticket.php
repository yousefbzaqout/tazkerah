<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Ticket extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    public $timestamps = false;

    protected $fillable = [
        'id',
        'tenant_id',
        'seat_id',
        'user_id',
        'status',
        'totp_seed',
        'signature',
        'created_at',
    ];

    public function seat(): BelongsTo
    {
        return $this->belongsTo(Seat::class);
    }
}
