job "nginx-vault-demo" {
  datacenters = ["dc1"]
  type        = "service"

  group "nginx-group" {
    count = 1

    network {
      mode = "bridge"          # Service Mesh
      port "http" {
        to = 80
      }
    }

    service {
      name = "vault-nginx"
      port = "http"
      address_mode = "alloc"
      connect {
        sidecar_service {}     # Nomad поднимет Envoy рядом с Nginx
      }
    }

    task "nginx" {
      driver = "docker"

      vault {
        role = "nginx-backend"
      }

      identity {
        name = "vault_default"
        aud  = ["vault.io"]
        file = true
      }

      template {
        data = <<EOF
{{ with secret "kv/data/data/nginx-configs/backend1" }}
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
