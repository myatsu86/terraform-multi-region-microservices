# Adding Auto-Scaling Groups to the Fake-Service POV

This document is a walkthrough of every change made to migrate the three-tier fake-service demo from static EC2 instances to Auto-Scaling Groups (ASG). It explains *why* each change was needed so you can reason about it rather than just follow steps.

---

## Architecture: Before vs After

**Before**
```
internet ──► customer-profile-svc (EC2)  ──► account-svc (EC2)  ──► statement-svc (EC2)
             vpc-public / eu-central-1        vpc-private-1           vpc-private-2
             Public IP: 3.x.x.x              Private IP: 10.1.x.x   Private IP: 10.2.x.x
             upstream hardcoded to             upstream hardcoded to
             account instance private IP       statement instance private IP
```

**After**
```
internet ──► customer-profile-ALB  ──► account-ALB  ──► statement-ALB
             (public, port 80)          (internal)       (internal)
                  │                         │                 │
             ASG (1–3 t3.micro)        ASG (1–3 t3.micro)  ASG (1–3 t3.micro)
             vpc-public                vpc-private-1       vpc-private-2
             eu-central-1              eu-west-1           eu-west-2
```

Key differences:
- Upstreams are now **ALB DNS names** (stable), not **private IPs** (ephemeral, changes when instances replace).
- Binary is **self-pulled from S3** at boot, not pushed over SSH.
- Instances register themselves with the ALB target group automatically via ASG.

---

## The Core Problem: Private VPCs + No Internet

`vpc-private-1` (eu-west-1) and `vpc-private-2` (eu-west-2) have no internet route (no NAT, no IGW). The old approach used a Terraform `null_resource` provisioner to SSH-push the binary from the bastion. That breaks with ASG because:

1. ASG instances get dynamic private IPs — you can't pre-target them in Terraform.
2. New instances scale in/out without any Terraform trigger to push the binary.

**Solution: S3 + VPC Gateway Endpoints**

- Binary lives in an S3 bucket in eu-central-1.
- Each private VPC gets a free S3 **Gateway VPC Endpoint** — traffic to S3 routes through AWS's internal network, not the internet.
- Instances pull the binary at boot with `aws s3 cp`, using an **IAM Instance Profile** for credentials.
- The customer-profile instance (has internet) downloads from GitHub and uploads to S3 on first boot. Account and statement instances then pull from S3.

---

## Key Concepts

### Launch Template
A blueprint for EC2 instances: AMI, instance type, key pair, IAM profile, security groups, user_data. The ASG uses it to launch new instances.

### Auto-Scaling Group (ASG)
Manages a fleet of instances using the Launch Template. Key settings:
- `min_size` / `max_size` / `desired_capacity` — instance count bounds
- `vpc_zone_identifier` — list of subnets to spread instances across (multi-AZ)
- `target_group_arns` — ASG registers/deregisters instances with the ALB target group automatically
- `health_check_type = "ELB"` — instance is only considered healthy when the ALB can reach it

### S3 Gateway VPC Endpoint
A free routing rule that sends S3 traffic from a VPC to AWS's backbone instead of the public internet. It works by injecting a route into your VPC route table. No NAT Gateway needed.

### IAM Instance Profile
Attaches an IAM Role to an EC2 instance. The AWS CLI on the instance picks up the role credentials automatically — no access keys needed. We use it to grant `s3:GetObject` on the binary bucket.

### ALB DNS vs Private IP
An ALB DNS name (e.g. `account-alb-1234.eu-west-1.elb.amazonaws.com`) is stable forever. The private IP of an EC2 instance changes every time it's replaced. For ASG, always use ALB DNS as the upstream.

---

## Files Changed

### 1. `loadbalancer.tf` (moved from `scripts/`)

**What changed:**
- Renamed 3 duplicate `aws_lb_listener.http` resources → `http_customer_profile`, `http_account`, `http_statement`
- Removed `aws_lb_target_group_attachment` blocks — ASG handles registration via `target_group_arns`
- Fixed `security_groups` to use list syntax: `[module.ec2_xxx.security_group_id]`
- Added `health_check` blocks to all 3 target groups

**Why:** ALB target group attachments are for static instances. With ASG, instances register themselves.

```hcl
resource "aws_lb_target_group" "statement_tg" {
  name     = "statement-tg"
  port     = 9093          # the port the service listens on
  protocol = "HTTP"
  vpc_id   = module.vpc["vpc-private-2"].vpc_id

  health_check {
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
    timeout             = 5
  }
}
```

---

### 2. `s3.tf` (new file)

**What it does:**
- Creates the S3 bucket that holds the fake-service binary
- Blocks all public access
- Creates one S3 Gateway VPC Endpoint per private VPC

```hcl
resource "aws_s3_bucket" "fake_service_binary" {
  bucket = "fake-service-203932541249"   # globally unique: prefix + account ID
}

resource "aws_vpc_endpoint" "s3_private1" {
  region            = local.vpc_region["vpc-private-1"]
  vpc_id            = module.vpc["vpc-private-1"].vpc_id
  service_name      = "com.amazonaws.eu-west-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [module.vpc["vpc-private-1"].route_table_id]
}
```

**Why `route_table_ids`:** The Gateway Endpoint works by injecting a route into your VPC route table. You must tell it which route table to modify.

**Why no endpoint for vpc-public:** The customer-profile instance is in a public VPC with internet access — it downloads from GitHub directly and uploads to S3 over the internet.

---

### 3. `iam.tf` (new file)

**What it does:**
- Creates an IAM Role that EC2 instances can assume (`ec2.amazonaws.com` principal)
- Attaches a policy that allows `s3:GetObject` on the binary bucket
- Creates an Instance Profile that wraps the role (Instance Profiles are how roles attach to EC2)

```hcl
resource "aws_iam_role" "ec2_s3_role" {
  name = "fake-service-ec2-s3-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "fake-service-ec2-profile"
  role = aws_iam_role.ec2_s3_role.name
}
```

**Why no `region` attribute:** IAM is a global service — resources have no region.

---

### 4. `modules/ec2/variables.tf`

**What changed:**
- `subnet_id` (string) → `subnet_ids` (list of strings) — ASG needs all subnets to spread across AZs
- Added: `min_size`, `max_size`, `desired_capacity` — ASG scaling bounds
- Added: `target_group_arns` (list of strings) — which ALB target groups to register with
- Added: `iam_instance_profile_arn` — the Instance Profile to attach (required, no default)

---

### 5. `modules/ec2/main.tf`

**What changed:**
- `aws_instance` commented out
- Added `aws_launch_template` — the instance blueprint
- Added `aws_autoscaling_group` — the fleet manager

Key points in the Launch Template:
```hcl
user_data = base64encode(var.user_data)
# Launch Template requires base64; aws_instance accepted raw string
```

Key points in the ASG:
```hcl
health_check_type   = "ELB"          # use ALB to judge instance health
vpc_zone_identifier = var.subnet_ids  # span all 3 AZs
target_group_arns   = var.target_group_arns  # auto-register instances
```

---

### 6. `modules/ec2/output.tf`

**What changed:**
- Removed `private_ip`, `public_ip`, `instance_id` — these were per-instance outputs; ASGs don't have a single IP
- Kept `security_group_id` — still needed by ALB `security_groups` argument
- Added `asg_name` — useful for `aws autoscaling describe-auto-scaling-groups`

---

### 7. `scripts/statement.sh`

**What changed:** Added S3 binary download at boot.

```bash
# pull binary from S3 via VPC gateway endpoint (no internet needed)
aws s3 cp s3://fake-service-203932541249/fake-service /usr/bin/fake_service --region eu-central-1
sudo chmod 755 /usr/bin/fake_service
```

**Why `--region eu-central-1`:** The bucket is in eu-central-1. This instance runs in eu-west-2. The AWS CLI defaults to the instance's own region — you must override it to point at the bucket's region.

**Why no `sudo` on `aws s3 cp`:** user_data runs as root already.

---

### 8. `scripts/account.sh`

**Two changes:**

1. Added S3 binary download (same as statement.sh above).

2. Changed `UPSTREAM_PORT` from `9093` → `80`:
```bash
UPSTREAM_PORT="80"
```
**Why:** The upstream used to be the statement *instance* on port 9093. Now it's the statement *ALB*, which listens on port 80. The ALB then forwards to instances on 9093.

The `${upstream_ip}` template variable stays — it gets filled by `templatefile()` in `instance.tf` with the statement ALB DNS name.

---

### 9. `scripts/user-profile.sh`

**What changed:** `UPSTREAM_PORT` `9092` → `80` (same reasoning as account.sh — pointing to account ALB now, not a direct instance).

This script also uploads the binary to S3:
```bash
aws s3 cp fake-service s3://fake-service-203932541249/fake-service
```
This is the **bootstrap step** — customer-profile has internet, so it downloads from GitHub and uploads to S3. Account and statement instances then pull from there. No manual upload needed.

---

### 10. `instance.tf`

**What changed (all 3 modules):**

| Before | After |
|---|---|
| `for_each` over subnet IDs (3 module instances) | Single module call |
| `subnet_id = each.value` | `subnet_ids = module.vpc["xxx"].subnet_ids` |
| `name = "svc-${each.key}"` | `name = "svc"` |
| `upstream_ip = values(module.ec2_xxx)[0].private_ip` | `upstream_ip = aws_lb.xxx_alb.dns_name` |
| No `target_group_arns` | `target_group_arns = [aws_lb_target_group.xxx_tg.arn]` |
| No `iam_instance_profile_arn` | `iam_instance_profile_arn = aws_iam_instance_profile.ec2_profile.arn` |

**Why remove `for_each`:** The old design created one EC2 instance per subnet manually. The ASG now handles multi-AZ spreading internally — you just give it the list of subnets.

```hcl
module "ec2_account" {
  source     = "./modules/ec2"
  name       = "account-svc"
  subnet_ids = module.vpc["vpc-private-1"].subnet_ids   # all 3 subnets
  user_data  = templatefile("${path.module}/scripts/account.sh", {
    upstream_ip = aws_lb.statement_alb.dns_name          # ALB DNS, not instance IP
  })
  target_group_arns        = [aws_lb_target_group.account_tg.arn]
  iam_instance_profile_arn = aws_iam_instance_profile.ec2_profile.arn
  # ...
}
```

---

### 11. `provisioner.tf` — deleted

**Why:** The `null_resource` provisioners SSH-pushed the binary from the bastion to private instances. This is incompatible with ASG — you can't target dynamically-created instances with static Terraform resources. Binary delivery is now handled by user_data (S3 pull at boot).

---

### 12. `outputs.tf`

**What changed:** All outputs referenced dead module outputs (`public_ip`, `private_ip`) and assumed `for_each` on modules. Replaced with ALB DNS names and ASG names.

```hcl
output "app_url" {
  value = "http://${aws_lb.customer_profile_alb.dns_name}"
}
output "account_alb_dns"  { value = aws_lb.account_alb.dns_name }
output "statement_alb_dns" { value = aws_lb.statement_alb.dns_name }
output "customer_profile_asg_name" { value = module.ec2_customer_profile.asg_name }
output "account_asg_name"          { value = module.ec2_account.asg_name }
output "statement_asg_name"        { value = module.ec2_statement.asg_name }
```

---

## Post-Apply Checklist

```bash
terraform init   # re-init — new providers (IAM, S3, VPC endpoints, ASG resources)
terraform plan   # review: should show ~20+ new resources, all old EC2 instances destroyed
terraform apply
```

After apply:

1. **Wait ~3 minutes** for cloud-init to finish on all instances.

2. **Check ALB health** in the AWS Console → EC2 → Target Groups. All targets should be "healthy" (2 consecutive health checks pass before that). If account/statement are unhealthy, see note below.

3. **Hit the app:**
   ```bash
   curl http://$(terraform output -raw app_url)/
   # expect nested JSON with all three services: customer-profile → account → statement
   ```

4. **Check ASG:**
   ```bash
   aws autoscaling describe-auto-scaling-groups \
     --auto-scaling-group-names $(terraform output -raw statement_asg_name) \
     --region eu-west-2 \
     --query 'AutoScalingGroups[0].Instances[*].{ID:InstanceId,Health:HealthStatus}'
   ```

---

## Race Condition Note

If `account-svc` or `statement-svc` instances boot before `customer-profile-svc` finishes the S3 upload, their `aws s3 cp` will fail and the service won't start. The ALB will mark them unhealthy.

**Fix:** In the AWS Console, go to EC2 → Auto Scaling Groups → select the unhealthy ASG → Instance Management → terminate the unhealthy instances. The ASG will replace them immediately, and by then the binary is already in S3.

For a production setup you would add a retry loop or a lifecycle hook, but for a POV demo this is fine.

---

## File Map (Updated)

| File | Purpose |
|---|---|
| `terraform.tfvars` | Per-VPC CIDR, AZs, and region — change regions here |
| `vpc.tf` / `modules/vpc` | Three VPCs + subnets (for_each over `var.VPCs`) |
| `peering.tf` | Cross-region VPC peering (request + accepter) + routes |
| `s3.tf` | Binary bucket + S3 Gateway VPC Endpoints for private VPCs |
| `iam.tf` | IAM Role + Instance Profile for S3 access |
| `loadbalancer.tf` | ALBs + target groups + listeners for all 3 tiers |
| `instance.tf` / `modules/ec2` | One ASG per tier (Launch Template + ASG + Security Group) |
| `keypair.tf` | Generated key, registered per region, local `my-key.pem` |
| `scripts/statement.sh` | user_data: S3 binary pull + statement systemd unit |
| `scripts/account.sh` | user_data: S3 binary pull + account systemd unit (upstream = statement ALB) |
| `scripts/user-profile.sh` | user_data: GitHub download → S3 upload + customer-profile systemd unit (upstream = account ALB) |
| `outputs.tf` | ALB DNS names, app URL, ASG names |
