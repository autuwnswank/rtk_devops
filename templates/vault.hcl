ui = true
data_dir = "/opt/vault"

storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1 
# пока отключаем TLS для простоты первичной настройки
}

# отключаем блокировку памяти в контейнерах/вм, если нет привилегий root
disable_mlock = true
