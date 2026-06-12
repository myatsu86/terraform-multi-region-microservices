# fake-service 3-tier POV

"HelloCloudBank | Retail Banking" demo: three [fake-service](https://github.com/nicholasjackson/fake-service) instances chained across three peered VPCs — **each in a different AWS region**.

```
internet ──► customer-profile-svc ──► account-svc ──► statement-svc
             vpc-public  :9091        vpc-private-1   vpc-private-2
             10.0.0.0/16              10.1.0.0/16     10.2.0.0/16
             eu-central-1             eu-west-1       eu-north-1
             (IGW, public IP)         :9092           :9093
                     └── cross-region VPC peering + routes ──┘
```

- Regions are set per VPC in `terraform.tfvars`; everything else (AMI lookup, key pairs, peering, routes) adapts automatically. Same-region and cross-region mixes both work.
- Cross-region peering cannot be auto-accepted in one step, so each peering is a *request* in one region plus an `aws_vpc_peering_connection_accepter` in the other (`peering.tf`).
- AMI IDs and EC2 key pairs are region-scoped, so the Ubuntu AMI is looked up per region (`data.tf`) and the same public key is registered in every region in use (`keypair.tf`) — the single local `my-key.pem` opens all instances.
- Each VPC has one subnet (module `modules/vpc`); the private VPCs have **no internet route** (no NAT/IGW).
- Each service is a `t3.micro` Ubuntu 22.04 instance (module `modules/ec2`) running the binary as a systemd unit, written by the user_data scripts in `scripts/`.
- All instances share one Terraform-generated ED25519 key pair (`keypair.tf`); your local copy is `my-key.pem`.

## Usage

```bash
terraform init
terraform apply -auto-approve

# verify (allow ~30s after apply for the chain to settle)
curl http://$(terraform output -raw bastion_public_ip):9091/
# expect "code": 200 at every level with all three services nested

terraform destroy -auto-approve
```

The two `null_resource` provisioners may show "Still creating" for 2–4 minutes — that's `cloud-init status --wait` blocking until the bastion finishes apt + binary download. That is normal.

## Deploying the binary to private instances (`provisioner.tf` + `scripts/deploy-binary.sh`)

**The problem:** `account-svc` and `statement-svc` run in private VPCs with no internet access, so they can't download the fake-service binary themselves. The standard approach — Terraform's `file` provisioner with `bastion_host` (SSH jump host) — was tried first and **does not work reliably**: the 22 MB binary is tunneled from the local machine through the bastion, and bulk SSH uploads stall on the local uplink (transfer froze at 32 KB, leaving `terraform apply` hanging at "Still creating" indefinitely). Small SSH traffic works fine; large transfers from the laptop do not.

**The solution:** a custom script, `scripts/deploy-binary.sh`, that flips the direction — the binary never leaves AWS:

1. The bastion (`customer-profile-svc`, public subnet) downloads the binary from GitHub in its own user_data (`scripts/user-profile.sh`).
2. Terraform's `null_resource` connects **only to the bastion** and uploads two tiny files: the SSH private key (`~/.ssh/tf_key`) and `deploy-binary.sh`.
3. `remote-exec` runs the script on the bastion with the target's private IP and service name, e.g. `deploy-binary.sh 10.1.1.x account.service`.
4. The script waits for cloud-init on both machines (bastion: binary downloaded; target: systemd unit written), then `scp`s the binary bastion → private instance over VPC peering (sub-second), atomically moves it to `/usr/bin/fake_service`, and restarts the service.

**Result:** only KB-sized control files travel from the laptop; the 22 MB binary moves entirely inside AWS. Re-deploys happen automatically via `triggers` whenever an instance is replaced or the script changes.

## Why the security groups allow ICMP

Each instance's security group (`modules/ec2/main.tf`) has this rule alongside the TCP ones:

```hcl
ingress {
  from_port   = -1   # for ICMP these mean type/code, not ports; -1 = all
  to_port     = -1
  protocol    = "icmp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

**What ICMP is:** networks don't only carry application data (SSH, HTTP) — they also send small *service messages about the delivery itself*: "couldn't deliver", "host doesn't exist", and the one that matters here: **"your packet is too big for this path — resend it smaller"**. That's ICMP. Think of it as the postal service's own notification slips, separate from the actual letters.

**Why this setup needs it (Path MTU Discovery):**

1. Inside one region, EC2 instances talk with jumbo packets (9001 bytes).
2. The link **between regions** (cross-region VPC peering) only carries packets up to **1500 bytes**.
3. The instances don't know that — their network cards are set to 9001, so the bastion sends jumbo packets toward the other region. The network drops them and sends back the ICMP "too big, max 1500" message.
4. The sender reads that message, repacks into smaller packets, and the transfer flows. This self-correction is automatic — **but only if the message arrives.**

Without the rule above, the security group (which only allowed TCP 22 + the app port) silently drops that message. The sender never learns why its packets vanish and retransmits jumbo packets forever. The symptom: **SSH login works (small packets fit under 1500), but the 22 MB binary copy stalls after a few KB and never finishes** — a hang with no error, easily mistaken for a Terraform or peering problem.

The rule opens no doors for actual data — TCP rules stay exactly as strict as before. Bonus: `ping` between instances works, which is handy for debugging. For production you'd narrow it to ICMP type 3 code 4 ("fragmentation needed") from your VPC CIDRs only.

## Manual SSH into a private instance

Interactive sessions are small traffic, so a jump works fine for those:

```bash
ssh -i my-key.pem -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    -o ProxyCommand="ssh -i my-key.pem -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -W %h:%p ubuntu@$(terraform output -raw bastion_public_ip)" \
    ubuntu@$(terraform output -raw account_private_ip)
```

(Use `statement_private_ip` for statement-svc.)

## File map

| File | Purpose |
|---|---|
| `terraform.tfvars` | per-VPC CIDR, AZ and **region** — change regions here |
| `vpc.tf` / `modules/vpc` | three VPCs + subnets (for_each over `var.VPCs`) |
| `peering.tf` | cross-region VPC peering (request + accepter) + routes |
| `instance.tf` / `modules/ec2` | the three instances + security groups (TCP + ICMP) |
| `keypair.tf` | generated key, registered per region, local `my-key.pem` |
| `provisioner.tf` | binary deployment to private instances (see above) |
| `scripts/*.sh` | user_data (systemd units) + `deploy-binary.sh` |
| `outputs.tf` | bastion IP, app URL, private IPs |
