package ovh.testdomain.project.models;

import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.Id;
import javax.validation.constraints.NotBlank;
import java.util.Date;

@Entity
public class Visit {
    @Id
    @GeneratedValue
    private Long id;

    @NotBlank
    private String ip;

    @NotBlank
    private Date timestamp;


    public Visit() {
        setTimestamp(new Date());
    }

    public void setIp(String ip) {
        this.ip = ip;
    }

    public String getIp() {
        return ip;
    }

    private void setTimestamp(Date timestamp) {
        this.timestamp = timestamp;
    }

    public Date getTimestamp() {
        return timestamp;
    }
}
