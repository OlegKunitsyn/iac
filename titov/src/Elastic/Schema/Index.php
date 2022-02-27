<?php

namespace App\Elastic\Schema;

/**
 * @Annotation
 * @Target("CLASS")
 */
final class Index
{
    public $name;
    public $type = 'doc';
    public $alias;
}
