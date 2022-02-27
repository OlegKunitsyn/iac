<?php

namespace App\Elastic\Schema;

/**
 * @Annotation
 * @Target("ANNOTATION")
 */
final class Fields
{
    /**
     * @var string
     */
    public $name;

    /**
     * @var App\Elastic\Schema\Field
     */
    public $field;
}
