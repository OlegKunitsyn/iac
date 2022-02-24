package ovh.testdomain.project.controllers;

import io.swagger.v3.oas.annotations.Hidden;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import ovh.testdomain.project.Main;
import ovh.testdomain.project.models.Visit;
import ovh.testdomain.project.repositories.VisitRepository;

import javax.servlet.http.HttpServletRequest;

@RestController
public class IndexController {
    @Autowired
    private VisitRepository repository;

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
