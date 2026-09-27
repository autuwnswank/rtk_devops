data_dir   = "/opt/nomad"
region     = "global"
datacenter = "dc1"
log_level = "DEBUG"
bind_addr = "0.0.0.0"

server {
  enabled          = true
  bootstrap_expect = 3
  oidc_issuer = "nomad"
}

client {
  enabled = true
  options {
    "driver.raw_exec.enable" = "1"
    "driver.exec.enable"     = "1"
  }
}

advertise {
  http = "10.130.0.13"
  rpc  = "10.130.0.13"
  serf = "10.130.0.13"
}

consul {
  address = "10.130.0.13:8500"
}

vault {
  enabled = true
  address = "http://10.130.0.13:8200"

  default_identity {
    aud = ["vault.io"]
    ttl = "1h"
    file = true
  }

  jwt_auth_backend_path = "jwt"
}

