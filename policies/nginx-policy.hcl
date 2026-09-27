path "sys/internal/ui/mounts/nginx-configs/backend1" {
  capabilities = ["read"]
}

path "kv/data/data/nginx-configs/backend1" {
  capabilities = ["create", "update", "read"]
}

path "sys/internal/ui/mounts/nginx-configs/backend2" {
  capabilities = ["read"]
}

path "kv/data/data/nginx-configs/backend2" {
  capabilities = ["create", "update", "read"]
}
