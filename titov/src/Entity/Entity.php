<?php

namespace App\Entity;

use DateTimeInterface;
use JsonSerializable;

abstract class Entity implements JsonSerializable
{
    private $id;

    public function getId(): ?string
    {
        return $this->id;
    }

    public function setId(string $value): self
    {
        $this->id = $value;
        return $this;
    }

    public function jsonSerialize()
    {
        $fields = get_object_vars($this);
        foreach ($fields as $fieldName => $fieldValue) {
            if ($fieldValue instanceof DateTimeInterface) {
                $fields[$fieldName] = $fieldValue->format(DateTimeInterface::ISO8601);
            }
        }
        return $fields;
    }
}
