package ovh.testdomain.ride.repositories;

import org.springframework.data.repository.CrudRepository;
import ovh.testdomain.ride.models.Visit;

public interface VisitRepository extends CrudRepository<Visit, Long> {
}