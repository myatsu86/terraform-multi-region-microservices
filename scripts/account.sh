#!/bin/bash
exec > /var/log/account-service.log 2>&1
set -x

echo "Starting account service setup"

UPSTREAM_PORT="80"

# No apt install here: this subnet has no internet route, apt would stall cloud-init.
# Binary is deployed via Terraform null_resource provisioner (no internet access in private subnet)
# pull binary from S3 via VPC gateway endpoint (no internet needed)
aws s3 cp s3://fake-service-203932541249/fake-service /usr/bin/fake_service --region eu-central-1
sudo chmod 755 /usr/bin/fake_service

sudo cat > /usr/lib/systemd/system/account.service << EOF
[Unit]
Description=Account Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

Environment="LISTEN_ADDR=0.0.0.0:9092"
Environment="UPSTREAM_URIS=http://${upstream_ip}:$${UPSTREAM_PORT}"
Environment="NAME=account-svc"
Environment="MESSAGE=HelloCloudBank | Retail Banking | account-svc"

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
sudo systemctl enable account.service
sudo systemctl start account.service
sleep 1
sudo systemctl status account.service
sudo lsof -i -P | grep account