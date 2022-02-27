<?php

namespace App\Controller;

use App\Entity\Visit;
use App\Repository\VisitRepository;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

class IndexController extends AbstractController
{
    public function index(Request $request, VisitRepository $repository): Response
    {
        $visit = new Visit();
        $visit->setIp($request->getClientIp());
        $repository->persist($visit);

        return new Response('Symfony application. <a href="/api/visits">All visits</a>');
    }
}
