#!/bin/bash
exec > /var/log/statement-service.log 2>&1
set -x

echo "Starting statement service setup"

sudo apt update -y
sudo apt-get install net-tools zip curl jq tree unzip wget siege apt-transport-https ca-certificates software-properties-common gnupg lsb-release -y

sudo curl -LO https://github.com/nicholasjackson/fake-service/releases/download/v0.26.2/fake_service_linux_amd64.zip
sudo unzip fake_service_linux_amd64.zip

sudo rm -rf fake_service_linux_amd64.zip
sudo mv fake-service /usr/bin/fake_service
sudo chmod 755 /usr/bin/fake_service
sudo chown ubuntu:ubuntu /usr/bin/fake_service

sudo cat > /usr/lib/systemd/system/statement.service << 'EOF'
[Unit]
Description=Statement Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

Environment="LISTEN_ADDR=0.0.0.0:9093"
Environment="NAME=statement-svc"
Environment="MESSAGE=HelloCloudBank | Retail Banking | statement-svc"

ExecStart=/usr/bin/fake_service

User=ubuntu
Group=ubuntu

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target

EOF

sudo systemctl daemon-reload
sleep 1
sudo systemctl enable statement.service
sudo systemctl start statement.service
sleep 1
sudo systemctl status statement.service
sudo lsof -i -P | grep statement
