<?php

namespace App\Repository;

use App\Elastic\Schema;
use App\Entity\Entity;
use DateTime;
use DateTimeInterface;
use Doctrine\Common\Annotations\AnnotationReader;
use ReflectionClass;
use ReflectionException;
use Symfony\Component\HttpClient\Exception\ClientException;
use Symfony\Component\HttpClient\Exception\TransportException;
use Symfony\Contracts\HttpClient\Exception\ClientExceptionInterface;
use Symfony\Contracts\HttpClient\Exception\HttpExceptionInterface;
use Symfony\Contracts\HttpClient\Exception\RedirectionExceptionInterface;
use Symfony\Contracts\HttpClient\Exception\ServerExceptionInterface;
use Symfony\Contracts\HttpClient\Exception\TransportExceptionInterface;
use Symfony\Contracts\HttpClient\HttpClientInterface;

abstract class Repository
{
    private const HOST = 'http://127.0.0.1:9200';
    /**
     * @var HttpClientInterface
     */
    private $client;
    /**
     * @var string
     */
    private $indexName;
    /**
     * @var string
     */
    private $typeName;
    /**
     * @var string
     */
    private $aliasName;
    /**
     * @var string
     */
    private $idField;
    /**
     * @var array
     */
    private $fields = [];

    /**
     * @throws ReflectionException
     */
    public function __construct(HttpClientInterface $client)
    {
        $this->client = $client;

        $reader = new AnnotationReader();
        $reflector = new ReflectionClass($this->getEntityClass());
        $annotation = $reader->getClassAnnotation($reflector, Schema\Index::class);
        $this->indexName = $annotation->name;
        $this->typeName = $annotation->type;
        $this->aliasName = $annotation->alias;

        $reflector = new ReflectionClass($this->getEntityClass());
        $properties = $reflector->getProperties();
        foreach ($properties as $property) {
            $annotation = $reader->getPropertyAnnotation($property, Schema\Id::class);
            if (null !== $annotation) {
                $this->idField = $property->getName();
            }
            $annotation = $reader->getPropertyAnnotation($property, Schema\Field::class);
            if (null !== $annotation) {
                if ($annotation->fields) {
                    $fields = [];
                    foreach ($annotation->fields as $field) {
                        $fields[$field->name] = array_filter((array)$field->field);
                    }
                    $annotation->fields = $fields;
                }
                $this->fields[$property->getName()] = array_filter((array)$annotation);
            }
        }
    }

    abstract public function getEntityClass(): string;

    /**
     * @throws ClientExceptionInterface|ServerExceptionInterface|TransportExceptionInterface|RedirectionExceptionInterface
     */
    public function createIndex(): void
    {
        $schema = [
            'mappings' => [
                $this->typeName => [
                    'dynamic' => 'strict',
                    'properties' => $this->fields
                ]
            ]
        ];
        $this->client->request(
            'PUT',
            self::HOST . "/$this->indexName",
            [
                'headers' => ['Accept' => 'application/json'],
                'body' => json_encode($schema),
            ]
        );
        if ($this->aliasName) {
            $this->client->request(
                'PUT',
                self::HOST . "/$this->indexName/_alias/$this->aliasName",
                ['headers' => ['Accept' => 'application/json']]
            );
        }
    }

    /**
     * @throws ClientExceptionInterface|ServerExceptionInterface|TransportExceptionInterface|RedirectionExceptionInterface
     */
    public function updateSchema(): void
    {
        $schema = [
            'dynamic' => 'strict',
            'properties' => $this->fields
        ];
        $this->client->request(
            'PUT',
            self::HOST . "/$this->indexName/$this->typeName/_mapping",
            [
                'headers' => ['Accept' => 'application/json'],
                'body' => json_encode($schema),
            ]
        );
    }

    public function dumpIndex(): string
    {
        return json_encode([
            'dynamic' => 'strict',
            'properties' => $this->fields
        ]);
    }

    /**
     * @throws ClientExceptionInterface|ServerExceptionInterface|TransportExceptionInterface|RedirectionExceptionInterface
     */
    public function dropIndex(): void
    {
        $this->client->request(
            'DELETE',
            self::HOST . "/$this->indexName",
            ['headers' => ['Accept' => 'application/json']]
        );
    }

    /**
     * @throws HttpExceptionInterface|TransportExceptionInterface
     */
    public function find(string $id): ?Entity
    {
        try {
            $response = $this->client->request(
                'GET',
                self::HOST . "/" . ($this->aliasName ?? $this->indexName) . "/$this->typeName/$id",
                ['headers' => ['Accept' => 'application/json']]
            );
            return $this->toEntity(json_decode($response->getContent(), true));
        } catch (ClientException $e) {
            return null;
        }
    }

    /**
     * @throws HttpExceptionInterface|TransportExceptionInterface
     */
    public function findOne(array $must = [], array $mustNot = [], array $sort = [], $size = null, $from = null): ?Entity
    {
        $entities = $this->findBy($must, $mustNot, $sort, $size, $from);
        return count($entities) > 0 ? $entities[0] : null;
    }

    /**
     * @return Entity[]
     * @throws HttpExceptionInterface|TransportExceptionInterface
     */
    public function findBy(array $must = [], array $mustNot = [], array $sort = [], $size = null, $from = null): array
    {
        $query = [
            'filter' => [
                'bool' => [
                    'must' => $must,
                    'must_not' => $mustNot,
                ]
            ],
            'size' => $size ?? 100,
            'from' => $from ?? 0,
            'sort' => $sort
        ];
        $response = $this->client->request(
            'GET',
            self::HOST . "/" . ($this->aliasName ?? $this->indexName) . "/$this->typeName/_search",
            [
                'headers' => ['Accept' => 'application/json'],
                'body' => json_encode($query)
            ]
        );
        $result = [];
        $hits = json_decode($response->getContent(), true)['hits'];
        foreach ($hits['hits'] as $hit) {
            $result[] = $this->toEntity($hit);
        }
        return $result;
    }

    /**
     * @return array {int found, Entity[] entities}
     * @throws HttpExceptionInterface|TransportExceptionInterface
     */
    public function findByQuery(string $query, array $must = [], array $sort = [], $size = null, $from = null): array
    {
        $query = [
            'query' => [
                'query_string' => [
                    'query' => $query
                ],
            ],
            'filter' => [
                'bool' => [
                    'must' => $must
                ]
            ],
            'size' => $size ?? 100,
            'from' => $from ?? 0,
            'sort' => $sort
        ];
        $response = $this->client->request(
            'GET',
            self::HOST . "/" . ($this->aliasName ?? $this->indexName) . "/$this->typeName/_search",
            [
                'headers' => ['Accept' => 'application/json'],
                'body' => json_encode($query)
            ]
        );
        $response = json_decode($response->getContent(), true);
        $result = [
            'entities' => [],
            'found' => $response['hits']['total']
        ];
        foreach ($response['hits']['hits'] as $hit) {
            $result['entities'][] = $this->toEntity($hit);
        }
        return $result;
    }

    /**
     * @return array {int found, Entity[] entities, array aggregations}
     * @throws HttpExceptionInterface|TransportExceptionInterface
     */
    public function aggregateByQuery(string $query, array $aggregations, float $minScore = null): array
    {
        $query = [
            'query' => [
                'query_string' => [
                    'query' => $query
                ],
            ],
            'aggs' => $aggregations,
            'size' => 0
        ];
        if ($minScore) {
            $query['min_score'] = $minScore;
        }
        $response = $this->client->request(
            'GET',
            self::HOST . "/" . ($this->aliasName ?? $this->indexName) . "/$this->typeName/_search",
            [
                'headers' => ['Accept' => 'application/json'],
                'body' => json_encode($query)
            ]
        );
        $response = json_decode($response->getContent(), true);
        return [
            'aggregations' => $response['aggregations'],
            'found' => $response['hits']['total'],
        ];
    }

    /**
     * @throws HttpExceptionInterface|TransportExceptionInterface
     */
    public function persist(Entity $entity): Entity
    {
        if (get_class($entity) !== $this->getEntityClass()) {
            throw new TransportException('Incompatible entity submitted');
        }

        $array = array_intersect_key($entity->jsonSerialize(), $this->fields);
        $id = $this->idField ? $array[$this->idField] : $entity->getId();
        $method = !empty($id) ? 'PUT' : 'POST';

        $response = $this->client->request(
            $method,
            self::HOST . "/" . ($this->aliasName ?? $this->indexName) . "/$this->typeName/$id",
            [
                'headers' => ['Accept' => 'application/json'],
                'body' => json_encode($array),
            ]
        );
        $response = json_decode($response->getContent(), true);
        if (!empty($response['_id'])) {
            $entity->setId($response['_id']);
        }
        return $entity;
    }

    /**
     * @throws TransportExceptionInterface
     */
    public function remove(Entity $entity): void
    {
        $array = $entity->jsonSerialize();
        $id = $this->idField ? $array[$this->idField] : $entity->getId();
        if (empty($id)) {
            throw new TransportException('Unknown id');
        }

        $this->client->request(
            'DELETE',
            self::HOST . "/" . ($this->aliasName ?? $this->indexName) . "/$this->typeName/$id",
            ['headers' => ['Accept' => 'application/json']]
        );
    }

    /**
     * @throws TransportExceptionInterface
     */
    public function refresh(): void
    {
        $this->client->request(
            'POST',
            self::HOST . "/" . ($this->aliasName ?? $this->indexName) . "/_refresh",
            ['headers' => ['Accept' => 'application/json']]
        );
    }

    /**
     * @return Entity
     */
    public function toEntity(array $hit)
    {
        // init constructor
        $entity = $this->getEntityClass();
        /** @var Entity $entity */
        $entity = new $entity();

        // merge defaults
        foreach ($hit['_source'] as $key => $value) {
            if (($this->fields[$key]['type'] ?? null) === 'date' && !empty($value)) {
                $hit['_source'][$key] = DateTime::createFromFormat(DateTimeInterface::ISO8601, $value);
            }
        }
        $source = array_merge($entity->jsonSerialize(), $hit['_source']);

        $entity = unserialize(sprintf(
            'O:%d:"%s"%s',
            strlen($this->getEntityClass()),
            $this->getEntityClass(),
            strstr(serialize($source), ':')
        ));
        $entity->setId($hit['_id']);
        return $entity;
    }
}
