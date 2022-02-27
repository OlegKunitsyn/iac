<?php

namespace App\Controller;

use App\Repository\VisitRepository;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

class VisitController extends AbstractController
{
    public function index(VisitRepository $repository): Response
    {
        return new JsonResponse($repository->findByQuery('*'));
    }
}
