<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Seat extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    public $timestamps = false;

    protected $fillable = ['id', 'tenant_id', 'sector_id', 'seat_number', 'status', 'created_at'];

    public function sector(): BelongsTo
    {
        return $this->belongsTo(Sector::class);
    }
}
