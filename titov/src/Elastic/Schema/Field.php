<?php

namespace App\Elastic\Schema;

/**
 * @Annotation
 * @Target("PROPERTY", "ANNOTATION")
 */
final class Field
{
    /**
     * @var string
     * @Enum({"string", "boolean", "double", "date", "integer"})
     */
    public $type;

    /**
     * @var string
     * @Enum({"dateOptionalTime"})
     */
    public $format;

    /**
     * @var string
     * @Enum({"no", "not_analyzed"})
     */
    public $index;

    /**
     * @var string
     * @Enum({"english", "german", "french", "cjk"})
     */
    public $analyzer;

    /**
     * @var array
     */
    public $fields;
}
