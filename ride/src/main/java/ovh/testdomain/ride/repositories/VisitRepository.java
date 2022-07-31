package ovh.testdomain.ride.repositories;

import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;
import ovh.testdomain.ride.models.Visit;

@Repository
public interface VisitRepository extends CrudRepository<Visit, Long> {
}