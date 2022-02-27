<?php

namespace App\Command;

use App\Repository\VisitRepository;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Contracts\HttpClient\Exception\HttpExceptionInterface;
use Symfony\Contracts\HttpClient\Exception\TransportExceptionInterface;

class DropIndexCommand extends Command
{
    protected static $defaultName = 'app:elastic:drop';
    /**
     * @var VisitRepository
     */
    private $repository;

    protected function configure()
    {
        $this->setDescription('Delete index.');
    }

    public function __construct(VisitRepository $repository)
    {
        parent::__construct();
        $this->repository = $repository;
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        try {
            $this->repository->dropIndex();
            return Command::SUCCESS;
        } catch (HttpExceptionInterface|TransportExceptionInterface $e) {
            $output->writeln($e->getMessage());
            return Command::SUCCESS;
        }
    }
}
