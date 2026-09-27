job "nginx-frontend-demo" {
  datacenters = ["dc1"]
  type        = "service"

  group "frontend-group" {
    count = 1

    network {
      mode = "bridge"
      port "http" {
        to = 80
      }
    }

    service {
      name = "frontend-nginx"
      port = "http"
      address_mode = "alloc"
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "vault-nginx"  # ← Имя ПЕРВОГО сервиса
              local_bind_port  = 8080            # ← Порт для локального доступа
            }
          }
        }
      }
    }

    task "nginx" {
      driver = "docker"

      vault {
        role = "nginx-frontend"
      }

      identity {
        name = "vault_default"
        aud  = ["vault.io"]
        file = true
      }

      template {
        data = <<EOF
{{ with secret "kv/data/data/nginx-configs/backend2" }}
{{ .Data.data.config_file }}
{{ end }}
EOF
        destination = "local/nginx.conf"
      }

      config {
        image = "nginx:alpine"
        ports = ["http"]
        volumes = [
          "local/nginx.conf:/etc/nginx/nginx.conf"
        ]
      }
    }
  }
}
