#!/bin/bash
#
# deploy-binary.sh — runs ON the bastion host (customer-profile-svc).
#
# Copies the fake-service binary from this machine to one private instance
# and (re)starts its systemd service there. Called by Terraform, see
# provisioner.tf:
#
#   ./deploy-binary.sh <target_private_ip> <service_name>
#   e.g. ./deploy-binary.sh 10.1.1.42 account.service
#
set -euo pipefail # stop immediately if any command fails

TARGET_IP="$1"
SERVICE="$2"
BINARY="/usr/bin/fake_service"

# SSH settings for every hop to the target:
#   - authenticate with the key Terraform uploaded to ~/.ssh/tf_key
#   - don't record host keys (instances are recreated often, IPs get reused)
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $HOME/.ssh/tf_key"

echo "==> [1/4] Waiting for the bastion's boot setup (it downloads the binary)..."
cloud-init status --wait > /dev/null 2>&1 || true
test -x "$BINARY" # fail if the download didn't happen

echo "==> [2/4] Waiting for $TARGET_IP's boot setup (it writes the systemd unit)..."
ssh $SSH_OPTS ubuntu@"$TARGET_IP" "cloud-init status --wait > /dev/null 2>&1 || true"

echo "==> [3/4] Copying the binary to $TARGET_IP ..."
scp $SSH_OPTS "$BINARY" ubuntu@"$TARGET_IP":/tmp/fake_service.new

echo "==> [4/4] Installing the binary and starting $SERVICE ..."
# mv is an atomic swap, so this is safe even while the service is mid-restart.
ssh $SSH_OPTS ubuntu@"$TARGET_IP" "
  sudo chown root:root /tmp/fake_service.new &&
  sudo chmod 755 /tmp/fake_service.new &&
  sudo mv /tmp/fake_service.new $BINARY &&
  sudo systemctl restart $SERVICE &&
  sleep 2 &&
  systemctl is-active $SERVICE
"

echo "==> Done: $SERVICE is running on $TARGET_IP"
