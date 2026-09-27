#Прокинуть Envoy с российских зеркал, так как Docker Hub недоступен из РФ
sudo tee /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["https://mirror.gcr.io", "https://dockerhub.timeweb.cloud"]
}
EOF
sudo systemctl restart docker
consul intention create frontend-nginx vault-nginx
User -> HTTPS -> frontend Nginx -> proxy_pass -> localhost:8080 (sidecar frontend)
    -> mTLS -> sidecar backend -> backend Nginx -> "Derived straight from Vault"
