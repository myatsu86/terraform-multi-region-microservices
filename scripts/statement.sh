#!/bin/bash
exec > /var/log/statement-service.log 2>&1
set -x

echo "Starting statement service setup"

# No apt install here: this subnet has no internet route, apt would stall cloud-init.
# Binary is deployed via Terraform null_resource provisioner (no internet access in private subnet)


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