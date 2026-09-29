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
      port "https" {
	to = 443
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
              destination_name = "vault-nginx"  #  Имя первого сервиса
              local_bind_port  = 8080            #  Порт для локального доступа, реверс прокси на него настроен
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
#!/bin/sh

FILE="/etc/nginx/ssl/bundle.pem"
SIZE1=$(wc -c < "$FILE")
sleep 2
SIZE2=$(wc -c < "$FILE")

# если размер не меняется то файл дописан, можно чистить кэш
if [ "$SIZE1" = "$SIZE2" ]; then
    wget http://127.0.0.1:80/clear > /dev/null 2>&1
fi

exit 0
EOF
        destination = "local/clear_cache.sh"
        perms = "0755"
      }

      template {
        data = <<EOF
function read_bundle(r) {
    console.log('njs: read ' + data.length + ' bytes');
    let data = '';
    const zone = 'kv';
    const path = '/etc/nginx/ssl/bundle.pem';  // Путь внутри контейнера
    const key = 'bundle';
    const cache = zone && ngx.shared && ngx.shared[zone];

    // Проверяем кэш
    if (cache) {
        data = cache.get(key) || '';
        if (data) return data;
    }

    // Читаем файл с диска
    try {
        data = fs.readFileSync(path, 'utf8');
    } catch (e) {
        r.log('Error reading bundle: ' + e);
        data = '';
    }

    // Кладём в кэш
    if (cache && data) {
        cache.set(key, data);
    }
    console.log('njs: read ' + data.length + ' bytes');
    return data;
}

function js_cert(r) {
    return read_bundle(r);
}

function js_key(r) {
    return read_bundle(r);
}

function clear_cache(r) {
    const cache = ngx.shared.kv;
    if (cache) {
        cache.clear();
        r.return(200, 'cache cleared');
    } else {
        r.return(500, 'cache not found');
    }
}
export default { js_cert, js_key, clear_cache };
EOF
        destination = "local/njs/ssl_loader.js"
      }

      template {
        data = <<EOF
{{ with secret "pki_int/issue/nomad-role" "common_name=backend.global.nomad" "ttl=2m" "private_key_format=pkcs8" }}
{{ .Data.certificate }}
{{ .Data.private_key }}
{{ .Data.issuing_ca }}
{{ end }}
EOF

        destination = "local/ssl/bundle.pem"
        change_mode = "script"
        change_script {
          command = "/etc/nginx/clear_cache.sh"
        }
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
        image = "wsandwitch/nginx:latest"
        force_pull = true
        ports = ["http", "https"]
        volumes = [
          "local/nginx.conf:/etc/nginx/nginx.conf",
          "local/ssl:/etc/nginx/ssl",
          "local/njs:/etc/nginx/njs",
          "local/clear_cache.sh:/etc/nginx/clear_cache.sh"
        ]
      }
    }
  }
}
