#!/bin/bash
wget https://hashicorp-releases.yandexcloud.net/vault/1.21.4/vault_1.21.4_linux_amd64.zip;
#готовим системные службы и конфиги
sudo touch /etc/systemd/system/vault.service;
sudo mkdir -p /etc/vault.d/; sudo cp ./templates/vault.hcl /etc/vault.d/vault.hcl;
sudo cp ./templates/vault.service /etc/systemd/system/vault.service;
#установка vault
unzip vault_1.21.4_linux_amd64.zip;
sudo mv vault /usr/local/bin/;
sudo chmod +x /usr/local/bin/vault;
sudo systemctl enable vault.service;
sudo systemctl restart vault.service;
#проверка
vault version;
sudo systemctl status vault.service;

