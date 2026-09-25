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
<<<<<<< HEAD
  http = "10.130.0.14"
  rpc  = "10.130.0.14"
  serf = "10.130.0.14"
=======
  http = "10.130.0.3"
  rpc  = "10.130.0.14"
  serf = "10.130.0.7"
>>>>>>> 4c1dcfcec23f281deb8cc7cf11f6dbf72dad2ffc
}

consul {
  address = "127.0.0.1:8500"
}

vault {
  enabled = true
  address = "http://10.130.0.13:8200" 
  #token goes here
}


