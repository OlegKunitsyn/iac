package ovh.testdomain.ride.controllers;

import io.swagger.v3.oas.annotations.Hidden;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import ovh.testdomain.ride.Main;
import ovh.testdomain.ride.models.Visit;
import ovh.testdomain.ride.repositories.VisitRepository;

import javax.servlet.http.HttpServletRequest;

@RestController
public class IndexController {
    private final VisitRepository repository;

    public IndexController(VisitRepository repository) {
        this.repository = repository;
    }

    @Hidden
    @GetMapping("/")
    public String index(HttpServletRequest request) {
        Visit visit = new Visit();
        visit.setIp(request.getRemoteAddr());
        repository.save(visit);

        StringBuilder sb = new StringBuilder();
        sb
                .append("Spring Boot application v.")
                .append(Main.class.getPackage().getImplementationVersion())
                .append("<br>")
                .append("<a href='/actuator'>App status</a>")
                .append("<br>")
                .append("<a href='/swagger-ui.html'>Swagger</a>");
        return sb.toString();
    }
}
