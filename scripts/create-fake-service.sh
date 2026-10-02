#!/bin/bash

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
  echo "Usage: $0 <hostname> <service-name> <port> [upstream-uri:port]"
  echo "Example (with upstream):    $0 account-instance account 9092 10.2.11.31:9093"
  echo "Example (without upstream): $0 statement-instance statement 9093"
  exit 1
fi

HOSTNAME=$1
SERVICE_NAME=$2
PORT=$3
UPSTREAM_URI=${4:-""}

echo "SSH into $HOSTNAME ....."
ssh "$HOSTNAME" bash -s "$SERVICE_NAME" "$PORT" "$UPSTREAM_URI" << 'ENDSSH'
SERVICE_NAME=$1
PORT=$2
UPSTREAM_URI=$3

sudo mv fake-service /usr/bin/fake_service
sudo chmod 755 /usr/bin/fake_service
sudo chown ubuntu:ubuntu /usr/bin/fake_service

UPSTREAM_LINE=""
if [ -n "$UPSTREAM_URI" ]; then
  UPSTREAM_LINE="Environment=\"UPSTREAM_URIS=http://${UPSTREAM_URI}\""
fi

sudo tee /usr/lib/systemd/system/${SERVICE_NAME}.service > /dev/null << EOF
[Unit]
Description=${SERVICE_NAME}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

Environment="LISTEN_ADDR=0.0.0.0:${PORT}"
${UPSTREAM_LINE}
Environment="NAME=${SERVICE_NAME}"
Environment="MESSAGE=HelloCloudBank | Retail Banking | ${SERVICE_NAME}"

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
sudo systemctl enable ${SERVICE_NAME}.service
sudo systemctl start ${SERVICE_NAME}.service
sleep 1
sudo systemctl status ${SERVICE_NAME}.service
sudo lsof -i -P | grep ${SERVICE_NAME}
ENDSSH
