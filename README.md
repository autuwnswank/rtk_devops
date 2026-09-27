# Техническое задание
1. Поднять кластер Nomad и Consul
2. Поднять Vault
3. В Vault поднять два KV-хранилища для конфигов веб-сервисов
4. В Vault настроить выпуск сертификатов (HTTPS)
5. Взаимодействие должно бытьь организовано по паттерну Sidecar
## 1. Установка кластера
Архитектура требует минимум 3 ВМ для составления кворума Raft для Nomad, в котором 1 ВМ - Leader (планировщик и распределитель задач для кластера)
Минимум 3 ВМ составляют архитектуру, где Leader-ВМ может отдать задачу себе же для исполнения.
Основной скрипт установки - install.sh. Его необходимо запустить на всех 3 ВМ, предварительно отредактировав шаблоны для каждого продукта. 
Скрипт скачивает бинари и устанавливает системные службы для Nomad и Consul. 
Предусмотрено использование Yandex-зеркал для установки продуктов HashiCorp.
### 1.1 Установка зависимостей
Единственный скрипт, который запускается на этом этапе - cni_plugins_sidecar_download.sh. 
Его задача - загрузка cni плагинов а также загрузка модулей ядра, необходимых для Service Mesh (режима работы сети для Sidecar).
Запуск:
```
sudo ./cni_plugins_sidecar_download.sh
```
Также, для реализации Sidecar необходим докер-образ Envoy. Необходимо подключить российские зеркала и перезагрузить службу docker:
```
$ sudo tee /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["https://mirror.gcr.io", "https://dockerhub.timeweb.cloud"]
}
EOF

$ sudo systemctl restart docker
```
### 1.2 Редактирование шаблонов.
Шаблон - основная конфигурация для работы сервисов Nomad, Consul и Vault, имеющая формат .hcl.
Что редактируем:
1. templates/consul.hcl:
   ```
   node_name = "consul-node-3" # уникальное имя Вашей ноды в кластере
   ...
   retry_join = ["10.130.0.3", "10.130.0.14", "10.130.0.13"] # IP-адреса в моей задаче, это три машины в Yandex Cloud, здесь должны быть адреса ваших машин
   ...
   bind_addr = "10.130.0.13" #IP-адрес машины, на которую будет установлен сервис
   ```
2. templates/nomad.hcl:
   ```
   advertise {
      http = "10.130.0.13" #IP-адрес машины, на которую будет установлен сервис
      rpc  = "10.130.0.13"
      serf = "10.130.0.13"
   }
   ...
   consul {
      address = "10.130.0.13:8500" #Тот же IP, что и в advertise, порт не меняем
    }

   vault {
      enabled = true
      address = "http://10.130.0.13:8200" # Здесь IP машины, на которую будет установлен Vault.
   ...
   }
   ```
Остальные Конфиги изменению не подлежат
### 1.3 Установка кластеров Nomad и Consul
Основной скрипт - install.sh.
Запуск:
```
sudo ./install.sh
```
После установки на всех трех хостах, проверить, что кластера собрались, можно так:
```
boxey@nomad-compute-3:~/rtk_devops$ nomad server members
Name                    Address      Port  Status  Leader  Raft Version  Build   Datacenter  Region
nomad-compute-1.global  10.130.0.3   4648  alive   false   3             1.11.3  dc1         global
nomad-compute-2.global  10.130.0.14  4648  alive   false   3             1.11.3  dc1         global
nomad-compute-3.global  10.130.0.13  4648  alive   true    3             1.11.3  dc1         global

==> View and manage Nomad servers in the Web UI: http://127.0.0.1:4646/ui/servers
boxey@nomad-compute-3:~/rtk_devops$ consul members
Node           Address           Status  Type    Build   Protocol  DC   Partition  Segment
consul-node-1  10.130.0.3:8301   alive   server  1.22.7  2         dc1  default    <all>
consul-node-2  10.130.0.14:8301  alive   server  1.22.7  2         dc1  default    <all>
consul-node-3  10.130.0.13:8301  alive   server  1.22.7  2         dc1  default    <all>
```
## 2 Установка Vault
Основные скрипты - install_vault.sh, vault_jwt_setup.sh, env.sh.
Скрипт install_vault.sh проводить на 1 ВМ (в моем случае это Leader-node, 10.130.0.13)
Запуск:
```
sudo ./install_vault.sh
```
Далее необходимо распечатать Vault. Инициализируем ключи распечатки вот такой командой:
```
vault operator init
```
Отсюда мы получим 5 ключей распечатки и один токен root. Их хранить в отдельном файле, **не коммитить**
Распечатываем Vault последовательностью команд:
```
vault operator unseal
Key (will be hidden): <вставь Unseal Key 1>

# Введи ключ 2
vault operator unseal
Key (will be hidden): <вставь Unseal Key 2>

# Введи ключ 3
vault operator unseal
Key (will be hidden): <вставь Unseal Key 3>
```
После чего Vault будет инициализирован на прием-передачу. Проверим вот так:
```
vault status
```
Мы помним, что у нас есть root-токен - он необходим для аутентификация юзера в волте. В моей версии исполнения ТЗ, аутентификация только по токену.
Его необходимо вставить во вспомогательный скрипт env.sh и скрипт настройки Vault vault_jwt_setup_sh (```export VAULT_TOKEN=...```)
После чего запустим скрипт настройки ролей Vault:
```
sudo ./vault_jwt_setup.sh
```

consul intention create frontend-nginx vault-nginx
User -> HTTPS -> frontend Nginx -> proxy_pass -> localhost:8080 (sidecar frontend)
    -> mTLS -> sidecar backend -> backend Nginx -> "Derived straight from Vault"
