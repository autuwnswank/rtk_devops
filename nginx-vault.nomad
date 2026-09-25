job "nginx-vault-demo" {
  datacenters = ["dc1"]
  type        = "service"

  group "nginx-group" {
    count = 1

    # Блок vault на уровне группы — это нормально (дает права всем таскам внутри)
    vault {
      policies = ["nomad-server"]
    }

    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "vault-nginx"
      port = "http"
    }

    task "nginx" {
      driver = "docker"

      # !!! ПЕРЕНЕСЛИ СЮДА: Теперь template находится строго внутри блока task
      template {
        data = <<EOF
{{ with secret "secret/data/nginx-configs/backend1/data/config" }}
{{ .Data.data.config_file }}
{{ end }}
EOF

        destination = "local/nginx.conf"
        change_mode   = "signal"
        change_signal = "SIGHUP" 
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
