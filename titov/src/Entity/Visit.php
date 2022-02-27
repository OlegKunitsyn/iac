<?php

namespace App\Entity;

use DateTime;
use DateTimeInterface;
use Symfony\Component\Validator\Constraints as Assert;
use App\Elastic\Schema;

/**
 * @Schema\Index(name="visit", alias="visit_alias")
 */
class Visit extends Entity
{
    /**
     * @var string
     * @Schema\Field(type="string", index="not_analyzed")
     * @Assert\NotBlank
     */
    protected $ip;

    /**
     * @var DateTimeInterface
     * @Schema\Field(type="date", format="dateOptionalTime")
     * @Assert\NotBlank
     */
    protected $timestamp;

    public function __construct()
    {
        $this->setTimestamp(new DateTime());
    }

    public function getIp(): ?string
    {
        return $this->ip;
    }

    public function setIp(?string $value): self
    {
        $this->ip = $value;
        return $this;
    }

    public function getTimestamp(): DateTimeInterface
    {
        return $this->timestamp;
    }

    private function setTimestamp(DateTimeInterface $value): self
    {
        $this->timestamp = $value;
        return $this;
    }
}
