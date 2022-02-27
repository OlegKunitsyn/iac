<?php

namespace App\Repository;

use App\Entity\Visit;

class VisitRepository extends Repository
{
    public function getEntityClass(): string
    {
        return Visit::class;
    }
}
