data_dir   = "/opt/nomad"
region     = "global"
datacenter = "dc1"

bind_addr = "0.0.0.0"

server {
  enabled          = true
  bootstrap_expect = 3
}

client {
  enabled = true
  options {
    "driver.raw_exec.enable" = "1"
    "driver.exec.enable"     = "1"
  }
}

advertise {
  http = "10.0.2.15"
  rpc  = "10.0.2.15"
  serf = "10.0.2.15"
}

consul {
  address = "127.0.0.1:8500"
}
