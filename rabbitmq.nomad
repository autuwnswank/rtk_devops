job "rabbitmq" {
  datacenters = ["dc1"]
  type        = "service"

  group "rabbitmq" {
    count = 3

    network {
      mode = "host"
      port "amqp"       { static = 5672 }
      port "management" { static = 15672 }
      port "epmd"       { static = 4369 }
      port "clustering" { static = 25672 }
    }

    service {
      name = "rabbitmq"
      port = "amqp"
      tags = ["amqp"]
    }

    service {
      name = "rabbitmq-management"
      port = "management"
      tags = ["management", "http"]
#      check {
#        type     = "http"
#        path     = "/api/health/checks/alarms"
#        port     = "management"
#        interval = "15s"
#        timeout  = "5s"
#      }
    }

    # Один блок vault — либо policies здесь, либо role в task
    vault {
      role = "rabbitmq"
    }

    task "rabbitmq" {
      driver = "docker"

      template {
        data = <<-EOF
          {{ with secret "secret/data/rabbitmq/erlang-cookie" -}}
          RABBITMQ_ERLANG_COOKIE={{ .Data.data.value | toJSON }}
          {{- end }}
          {{ with secret "secret/data/rabbitmq/ui" -}}
          RABBITMQ_DEFAULT_PASS={{ .Data.data.value | toJSON }}
          {{- end }}
        EOF
        destination = "secrets/rabbitmq.env"
        env         = true
      }

      env {
        RABBITMQ_DEFAULT_USER             = "viewer"
        RABBITMQ_NODENAME                 = "rabbit@${attr.unique.hostname}"
        RABBITMQ_ENABLED_PLUGINS_FILE     = "/var/lib/rabbitmq/enabled_plugins"
        RABBITMQ_ENABLED_PLUGINS          = "rabbitmq_management,rabbitmq_peer_discovery_consul"
      }

      template {
        data = <<-EOF
          listeners.tcp.default = 5672
          management.tcp.port = 15672
          loopback_users.guest = false
          cluster_formation.peer_discovery_backend = consul
          cluster_formation.consul.host = 127.0.0.1
          cluster_formation.consul.port = 8500
          cluster_formation.consul.lock_timeout = 120
          cluster_formation.consul.svc_addr_auto = true
          cluster_formation.node_cleanup.only_log_warning = true
        EOF
        destination = "local/rabbitmq.conf"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      kill_timeout = "30s"

      config {
        image        = "rabbitmq:3.12-management-alpine"
        network_mode = "host"
        ports        = ["amqp", "management", "epmd", "clustering"]
      # Используем mount вместо volume_mount
        mount {
          type     = "bind"
          source   = "local/rabbitmq.conf"
          target   = "/etc/rabbitmq/rabbitmq.conf"
          readonly = true
        }
      }
    }
  }
}
