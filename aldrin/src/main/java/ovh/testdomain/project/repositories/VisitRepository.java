package ovh.testdomain.project.repositories;

import org.springframework.data.repository.CrudRepository;
import ovh.testdomain.project.models.Visit;

public interface VisitRepository extends CrudRepository<Visit, Long> {
}