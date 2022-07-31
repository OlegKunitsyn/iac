package ovh.testdomain.project.repositories;

import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;
import ovh.testdomain.project.models.Visit;

@Repository
public interface VisitRepository extends CrudRepository<Visit, Long> {
}