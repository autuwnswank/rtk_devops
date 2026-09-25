#!/bin/bash
wget https://hashicorp-releases.yandexcloud.net/nomad/1.11.3/nomad_1.11.3_linux_amd64.zip;
wget https://hashicorp-releases.yandexcloud.net/consul/1.22.7/consul_1.22.7_linux_amd64.zip;
#готовим системные службы и конфиги
sudo touch /etc/systemd/system/nomad.service; sudo touch /etc/systemd/system/consul.service;
sudo mkdir -p /etc/nomad.d/; sudo cp ./templates/nomad.hcl /etc/nomad.d/nomad.hcl;
sudo mkdir -p /etc/consul.d/; sudo cp ./templates/consul.hcl /etc/consul.d/consul.hcl;
sudo cp ./templates/nomad.service /etc/systemd/system/nomad.service;
sudo cp ./templates/consul.service /etc/systemd/system/consul.service;
#установка nomad
unzip nomad_1.11.3_linux_amd64.zip;
sudo mv nomad /usr/local/bin/;
sudo chmod +x /usr/local/bin/nomad;
#установка nomad
unzip consul_1.22.7_linux_amd64.zip;
sudo mv consul /usr/local/bin/;
sudo chmod +x /usr/local/bin/consul;
sudo systemctl enable nomad.service;
sudo systemctl restart nomad.service;
sudo systemctl enable consul.service;
sudo systemctl restart consul.service;
#установка terraform
#проверка
consul version;
nomad version;
sudo systemctl status nomad.service consul.service;
#удаление бинарей в текущей директории
sudo rm nomad_1.11.3_linux_amd64.zip;
sudo rm consul_1.22.7_linux_amd64.zip;

