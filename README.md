# Техническое задание
1. Поднять кластер Nomad и Consul
2. Поднять Vault
3. В Vault поднять два KV-хранилища для конфигов веб-сервисов
4. Взаимодействие должно быть организовано по паттерну Sidecar
5. В Vault настроить выпуск сертификатов (HTTPS)
## 1. Установка кластера
Версии компонент: nomad 1.11.3, consul 1.22.7, vault 1.21.4.

Архитектура требует минимум 3 ВМ для составления кворума Raft для Nomad, в котором 1 ВМ - Leader (планировщик и распределитель задач для кластера).

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
Основной скрипт - install.sh. Для удаления - uninstall.sh
Запуск:
```
sudo ./install.sh #установка
sudo ./uninstall.sh #удаление
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
Скрипт install_vault.sh проводить на 1 ВМ (в моем случае это Leader-node, 10.130.0.13).
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

Его необходимо вставить во вспомогательный скрипт env.sh и скрипт настройки Vault vault_jwt_setup_sh (```export VAULT_TOKEN=...```).

После чего запустим скрипт настройки ролей Vault:
```
sudo ./vault_jwt_setup.sh
```
## 3 Настройка конфигов KV для Vault
После настройки Vault необходимо доставить конфиги веб-сервисов nginx в KV хранилище. Делать можно вот так (пример для backend1):
```
vault kv put kv/data/nginx-configs/backend1   config_file='events {
    worker_connections 1024;
}
http {
    charset utf-8;

    server {
        listen 80;
        location / {
            return 200 "Derived straight from Vault";
            add_header Content-Type "text/plain; charset=utf-8";
        }
    }

    server {
        listen 443 ssl;
        server_name backend.global.nomad;

        ssl_certificate     /etc/nginx/ssl/bundle.pem;
        ssl_certificate_key /etc/nginx/ssl/bundle.pem;

        location / {
            return 200 "Derived straight from Vault";
            add_header Content-Type "text/plain; charset=utf-8";
        }
    }
}'

```
На данном этапе оба есть два конфига - nginx-frontend и nginx-backend.

Хранилище Vault настроено: http://81.26.176.66:8200/ui/vault/secrets/kv/kv/list/data/nginx-configs/
## 4 Sidecar
Sidecar - это вспомогательный процесс, который запускается рядом с основным приложением в одной аллокации и берёт на себя часть его сетевых задач. 

В кластере эту роль выполняет Envoy — прокси-сервер, которым управляет Consul.

Взаимодействие организовано следующим образом: 
```User -> HTTPS -> frontend Nginx -> proxy_pass -> localhost:8080 (sidecar frontend) -> mTLS -> sidecar backend -> backend Nginx -> "Derived straight from Vault"```

Сперва необходимо настроить правило Consul, которое разрешит трафик между сервисами, по умолчанию запрещен. Делается это так:
```
consul intention create frontend-nginx vault-nginx
```
Теперь нам надо задеплоить сервисы. Для упрощения сделан скрипт job_manager.sh. Этот скрипт останавливает, запускает и рестартует эти два сервиса.

Использование:
```
sudo ./job_manager.sh --restart
sudo ./job_manager.sh --stop
```
После поднятия через --restart проверить, что сервисы общаются друг с другом через sidecar, можно следующим образом:
1) Проверяем статус jobs (vault-demo = backend в данном примере)
```
boxey@nomad-compute-3:~/rtk_devops$ nomad job status
ID                   Type     Priority  Status   Submit Date
nginx-frontend-demo  service  50        running  2026-09-27T14:48:06Z
nginx-vault-demo     service  50        running  2026-09-27T14:47:51Z

```
2) Узнаем информацию об аллокации frontend (у него настроен upstream к backend)
```
boxey@nomad-compute-3:~/rtk_devops$ nomad job status nginx-frontend-demo
...
Allocations
ID        Node ID   Task Group      Version  Desired  Status   Created    Modified
98ac4dff  79e5690d  frontend-group  0        run      running  1h38m ago  1h37m ago
```
3) По аллокации заходим внутрь контейнера и оттуда curl на API Envoy - при наличии флага healthy сайдкар работает
```
boxey@nomad-compute-3:~/rtk_devops$ nomad alloc exec -task nginx 98ac4dff curl -s http://127.0.0.2:19001/clusters | grep vault-nginx | grep -i health

vault-nginx.default.dc1.internal.28d0b6e4-b1c4-dd24-05a2-c648347e99b2.consul::10.130.0.13:31121::health_flags::healthy

```
4) Более простая проверка: просто запрос на localhost:8080 внутри контейнера - если отдается конфиг backend, то sidecar frontend и backend успешно работют по service mesh
```
boxey@nomad-compute-3:~/rtk_devops$ nomad alloc exec -task nginx 98ac4dff curl -s http://127.0.0.1:8080
Derived straight from Vault
```



