sudo rm /etc/systemd/system/nomad.service; sudo rm -rf /etc/nomad.d/;
sudo rm /etc/systemd/system/consul.service; sudo rm -rf /etc/consul.d/;
sudo rm /usr/local/bin/consul;
sudo rm /usr/local/bin/nomad;
sudo systemctl stop nomad.service consul.service;
sudo systemctl disable nomad.service consul.service
systemctl daemon-reload;
