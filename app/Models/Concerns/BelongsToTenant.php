<?php

namespace App\Models\Concerns;

use App\Support\TenantContext;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * FR-016 defense-in-depth: Eloquent Global Scope mirroring PostgreSQL RLS fail-closed behavior.
 */
trait BelongsToTenant
{
    public static function bootBelongsToTenant(): void
    {
        static::addGlobalScope('tenant', function (Builder $builder): void {
            $tenantId = TenantContext::current();

            if ($tenantId === null || $tenantId === '') {
                $builder->whereRaw('1 = 0');

                return;
            }

            $builder->where(
                $builder->getModel()->getTable().'.tenant_id',
                $tenantId
            );
        });

        static::creating(function (Model $model): void {
            $tenantId = TenantContext::current();
            if ($tenantId !== null && $tenantId !== '' && empty($model->getAttribute('tenant_id'))) {
                $model->setAttribute('tenant_id', $tenantId);
            }
        });
    }
}
