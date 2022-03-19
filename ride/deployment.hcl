job "deployment" {
  datacenters = ["${datacenter}"]
  type        = "service"
  group "database" {
    count = 1
    network {
      mode = "bridge"
      port "tcp" {
        static = 9001
      }
    }
    service {
      name = "hsqldb"
      port = "tcp"
      connect {
        sidecar_service {}
      }
    }
    task "hsqldb" {
      driver = "java"
      config {
        class_path = "local/hsqldb-2.6.1.jar"
        class      = "org.hsqldb.server.Server"
        args       = ["--database.0", "file:tmp/ride", "--dbname.0", "ride"]
      }
      artifact {
        source = "https://repo1.maven.org/maven2/org/hsqldb/hsqldb/2.6.1/hsqldb-2.6.1.jar"
      }
      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
  group "application" {
    count = 2
    network {
      mode = "bridge"
      port "http" {
        static = 80
        to     = 8000
      }
    }
    service {
      name = "ride"
      port = "http"
      check {
        type     = "http"
        path     = "/actuator/health"
        interval = "10s"
        timeout  = "5s"
      }
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "hsqldb"
              local_bind_port  = 9001
            }
          }
        }
      }
    }
    task "ride" {
      driver = "java"
      config {
        jar_path = "local/ride-${version}.jar"
        args     = ["--spring.datasource.url=jdbc:hsqldb:hsql://localhost/ride"]
      }
      artifact {
        source = "https://gitlab.com/api/v4/projects/${project}/packages/generic/ride/${version}/ride-${version}.jar"
      }
      resources {
        cpu    = 1000
        memory = 256
      }
    }
  }
  update {
    max_parallel = 1
    auto_revert  = false
    canary       = 0
  }
}
