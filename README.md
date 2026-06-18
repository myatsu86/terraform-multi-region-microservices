# Fake-Service 3-Tier POV — HelloCloudBank Retail Banking

Three-tier demo using [fake-service](https://github.com/nicholasjackson/fake-service) chained across three peered VPCs, each in a different AWS region, with end-to-end HTTPS and Auto Scaling Groups.

```
User
 │ HTTPS:443
 ▼
retail-banking.myatsumon.info  (Route 53)
 │
 ▼
customer-profile-alb  [public, eu-central-1]  ──HTTP:9091──►  ASG: customer-profile-svc
                                                                      │ HTTPS:443 (VPC Peering)
                                                                      ▼
                                               account.myatsumon.info  (Route 53)
                                                                      │
                                                                      ▼
                                               account-alb  [internal, eu-west-1]  ──HTTP:9092──►  ASG: account-svc
                                                                                                         │ HTTPS:443 (VPC Peering)
                                                                                                         ▼
                                                                                    statement.myatsumon.info  (Route 53)
                                                                                                         │
                                                                                                         ▼
                                                                                    statement-alb  [internal, eu-west-2]  ──HTTP:9093──►  ASG: statement-svc
```

## Architecture

| Service | VPC | Region | Subnet | ALB Type |
|---|---|---|---|---|
| customer-profile-svc | vpc-customer-profile | eu-central-1 | Public (IGW) | Internet-facing |
| account-svc | vpc-account | eu-west-1 | Private (NAT) | Internal |
| statement-svc | vpc-statement | eu-west-2 | Private (NAT) | Internal |

**VPC Peering:**
- `vpc-customer-profile` ↔ `vpc-account`
- `vpc-account` ↔ `vpc-statement`

## Key Design Decisions

**ASG + NAT Gateway instead of provisioner**
Previously the fake-service binary was SSH-pushed from a bastion using a Terraform provisioner — incompatible with ASGs since instances launch dynamically. Each instance now downloads the binary from GitHub at boot via `user_data`. Account and statement instances (private subnets) reach GitHub through a NAT Gateway in the public subnet.

**ALB DNS as upstream (not private IPs)**
Instance IPs are ephemeral — they change every time the ASG replaces an instance. Each service's upstream is the next tier's ALB DNS name, which is stable regardless of instance churn.

**TLS termination at ALB**
HTTPS is terminated at each ALB. The ALB → instance leg uses plain HTTP on the service port. Internal service calls (customer-profile → account, account → statement) use HTTPS:443 over VPC Peering, resolving via Route 53 alias records.

## Auto Scaling

All three ASGs use the same configuration:
- `Min: 2 / Desired: 2 / Max: 3`
- Scaling policy: CPU target tracking at **50%**
- `health_check_type = "ELB"` — instances only receive traffic once the ALB marks them healthy
- Account and statement ASGs scale entirely within private subnets

## HTTPS + ACM + Route 53

- Wildcard certificate `*.myatsumon.info` provisioned in all 3 regions via ACM
- Route 53 A alias records managed by Terraform — automatically updated when ALBs are recreated
- Hosted zone (`myatsumon.info`) was registered manually in Route 53 (only manual step)

| DNS Record | ALB | Type |
|---|---|---|
| retail-banking.myatsumon.info | customer-profile-alb | Internet-facing |
| account.myatsumon.info | account-alb | Internal |
| statement.myatsumon.info | statement-alb | Internal |

## Security Groups (per ASG)

| Inbound | Port | Source |
|---|---|---|
| TCP | Service port (9091/9092/9093) | 0.0.0.0/0 |
| TCP | 443 | 0.0.0.0/0 |
| ICMP | All | 0.0.0.0/0 |

| Outbound | Port | Destination |
|---|---|---|
| All | All | 0.0.0.0/0 |

ICMP is required for Path MTU Discovery across cross-region VPC peering (peering is capped at 1500-byte packets while EC2 NICs use 9001-byte jumbo frames).

## Usage

```bash
terraform init
terraform apply

# verify
curl https://retail-banking.myatsumon.info/
# expect nested JSON: customer-profile → account → statement, all HTTP 200
```

Allow ~3 minutes after apply for cloud-init and ALB health checks to settle.

**Failover test:**
```bash
./scripts/failover-test.sh
# terminates one instance, watches ASG replace it, reports request success/fail count
```

## File Map

| File | Purpose |
|---|---|
| `terraform.tfvars` | Per-VPC CIDR, AZs, region, DNS vars |
| `vpc.tf` / `modules/vpc` | Three VPCs + subnets |
| `peering.tf` | Cross-region VPC peering + routes |
| `loadbalancer.tf` | ALBs, target groups, HTTPS listeners, Route 53 records |
| `instance.tf` / `modules/ec2` | ASG + Launch Template + Security Group per tier |
| `data.tf` | AMI lookup per region, ACM cert lookup, Route 53 zone |
| `keypair.tf` | ED25519 key pair registered per region |
| `variables.tf` | Input variables + locals |
| `outputs.tf` | ALB DNS names, ASG names |
| `scripts/user-profile.sh` | user_data: binary download + customer-profile systemd unit |
| `scripts/account.sh` | user_data: binary download + account systemd unit |
| `scripts/statement.sh` | user_data: binary download + statement systemd unit |
| `scripts/failover-test.sh` | Terminates an ASG instance and measures request continuity |
