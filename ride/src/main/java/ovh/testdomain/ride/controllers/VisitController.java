package ovh.testdomain.ride.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import ovh.testdomain.ride.models.Visit;
import ovh.testdomain.ride.repositories.VisitRepository;

@RestController
@RequestMapping("/api/visits")
public class VisitController {

    @Autowired
    private VisitRepository repository;

    @GetMapping("/{id}")
    public Visit findById(@PathVariable long id) {
        return repository.findById(id).orElseThrow(() -> new NotFoundException());
    }

    @GetMapping("/")
    public Iterable<Visit> findAll() {
        return repository.findAll();
    }
}
