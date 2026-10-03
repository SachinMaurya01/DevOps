# Terraform on AWS (tested on LocalStack) — a step-by-step guide

A small but production-shaped AWS stack, written to be **learned in stages**:

```
                    Internet
                       |
        +--------------+---------------+
        |                              |
   CloudFront (OAC)             Elastic IP :80/:443
        |                              |
   S3 bucket (private)      +----- VPC 10.x.0.0/16 ---------------------------+
        |  ^                |  public subnets   (IGW)                         |
        |  | read/write     |    frontend EC2: Ubuntu + nginx + Docker        |
        |  |                |    NAT gateway(s)                               |
        |  |                |  private subnets  (route out via NAT)           |
        |  +----------------+----backend EC2: Ubuntu + nginx + Docker         |
        |                   +-------------------------------------------------+
        | s3:ObjectCreated
        v
   SQS queue --> (after N failures) --> Dead-letter queue
        |
        v
   Lambda (Python)
```

| Piece | Where |
|---|---|
| VPC, subnets, Internet Gateway, NAT, route tables | `modules/network` |
| S3 bucket (private, encrypted, versioned in staging/prod) | `modules/storage` |
| SQS + DLQ + Lambda + S3 event notification | `modules/messaging` |
| Ubuntu EC2 for frontend and backend, nginx + Docker via user_data, IAM role, security groups | `modules/compute` |
| CloudFront in front of S3 | `modules/cdn` |
| dev / staging / prod differences | `locals.tf` (one map, keyed by workspace) |

> Verified 2026-10-03: `terraform init` + `validate` clean, `plan -var-file=envs/localstack.tfvars` → **40 to add** on LocalStack, workspaces `dev/staging/prod` created.

---

## 0. Quick start (TL;DR)

```bash
# 1. LocalStack running? Reuse it or start it:
curl -s http://localhost:4566/_localstack/health | head -c 200; echo
docker compose up -d   # skip if you already have localstack-aws on :4566

# 2. Init + workspaces (safe, no AWS calls):
terraform init
make workspaces        # creates dev/staging/prod, selects dev
# or manually:
# terraform workspace select -or-create dev
# terraform workspace select -or-create staging
# terraform workspace select -or-create prod
# terraform workspace select dev

# 3. Apply dev on LocalStack:
terraform plan  -var-file=envs/localstack.tfvars
terraform apply -var-file=envs/localstack.tfvars

# 4. Validate:
./scripts/validate.sh all localstack
./scripts/verify.sh    # uploads a file, waits for Lambda log line

# 5. Tear down dev:
terraform destroy -var-file=envs/localstack.tfvars
```

---

## Basic commands cheat sheet

| What | Command |
|---|---|
| Init providers | `terraform init` |
| Format / validate | `terraform fmt -recursive` · `terraform validate` |
| Workspaces | `terraform workspace list` · `show` · `select -or-create dev` |
| Plan / apply / destroy (LocalStack) | `terraform plan -var-file=envs/localstack.tfvars` · `apply` · `destroy` |
| Plan / apply (real AWS) | `terraform plan -var-file=envs/aws.tfvars` |
| Outputs | `terraform output` · `terraform output -raw bucket_name` |
| Make shortcuts | `make init` · `make workspaces` · `make plan ENV=dev` · `make apply ENV=dev` · `make validate-all ENV=dev` |
| Stage-by-stage | `make stage-network` · `make stage-storage` · `make stage-messaging` · `make stage-compute` |
| Validate a stage | `./scripts/validate.sh [network\|storage\|messaging\|compute\|all] [localstack\|aws]` |
| End-to-end async test | `./scripts/verify.sh` |
| LocalStack health | `curl -s http://localhost:4566/_localstack/health \| head -c 400` |
| AWS via LocalStack | `export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1` + `aws --endpoint-url http://localhost:4566 <svc> ...` |

`TARGET` selects the tfvars: `make plan ENV=staging TARGET=localstack` (default `TARGET=localstack`).

---

## Step 0 — Prerequisites

- Docker (with Compose v2)
- Terraform >= 1.6 (`terraform version`)
- AWS CLI v2 (only for the verify step; any credentials work with LocalStack)
- `make` (optional — every command is shown in full below)

---

## Step 1 — Start LocalStack + validate it

```bash
# Reuse existing container if you have one (e.g. localstack-aws on :4566):
curl -s http://localhost:4566/_localstack/health | head -c 400; echo

# Otherwise start this project's container:
docker compose up -d
docker compose ps
curl -s http://localhost:4566/_localstack/health | head -c 400; echo
# or: make localstack-up && make localstack-health
```

✅ Validate: health endpoint returns `200`, `s3/sqs/lambda/ec2/iam` available or running.
If your image asks for an auth token: `export LOCALSTACK_AUTH_TOKEN=...` first.

LocalStack-friendly notes in this repo:

- `docker-compose.yml` has a healthcheck, persists to `./.localstack/`, mounts the Docker socket (Lambda needs it).
- `providers.tf` routes all used services to `var.localstack_endpoint` when `use_localstack = true`, with dummy creds + `s3_use_path_style` + skip-checks.
- `envs/localstack.tfvars` sets `enable_cloudfront = false` (free tier lacks CloudFront — flip if yours has it).
- S3 gateway endpoint is auto-disabled on LocalStack (`enable_s3_gateway_endpoint = !var.use_localstack` in `main.tf`).
- TLS-only bucket policy is auto-disabled on LocalStack (plain HTTP in `bucket_policy.tf`).

---

## Step 2 — Learn the vocabulary (5 minutes)

| Term | Meaning here |
|---|---|
| **provider** | Plugin that talks to an API. `providers.tf` points it at LocalStack. |
| **resource** | One thing Terraform creates, e.g. `aws_vpc.this`. |
| **module** | A folder of resources with inputs (`variables.tf`) and outputs (`outputs.tf`). |
| **state** | Terraform's record of what it created. Never edit it by hand. |
| **workspace** | A separate copy of state. We use one per environment. |
| **plan / apply** | Preview changes / make them. Always read the plan. |

Read `providers.tf` and `locals.tf` first; they explain the two big ideas
(LocalStack switch, workspace-driven environments).

---

## Step 3 — Initialise + validate

```bash
terraform init
terraform fmt -check -recursive
terraform validate
```

✅ Validate: `Success! The configuration is valid.` Commit `.terraform.lock.hcl`, never state.

---

## Step 4 — Create the workspaces (dev / staging / prod)

Workspaces = separate states. The workspace name **is** the environment (`locals.tf` looks it up).

```bash
terraform workspace select -or-create dev
terraform workspace select -or-create staging
terraform workspace select -or-create prod
terraform workspace select dev
terraform workspace list
# expected:
#   default
# * dev
#   prod
#   staging
```

Shortcut: `make workspaces`.

Try the guard: `terraform workspace select default && terraform plan -var-file=envs/localstack.tfvars`
fails with `Workspace 'default' is not valid...`. Switch back to `dev`.

✅ Validate: `terraform workspace show` → `dev`. State dirs appear under `terraform.tfstate.d/<workspace>/` (gitignored).

What differs per workspace (`locals.tf`):

| Setting | dev | staging | prod |
|---|---|---|---|
| VPC CIDR | 10.10.0.0/16 | 10.20.0.0/16 | 10.30.0.0/16 |
| NAT gateways | 1 | 1 | one per AZ |
| Frontend / backend size | t3.micro / t3.small | t3.small / t3.medium | t3.medium / t3.large |
| Bucket versioning | off | on | on |
| Bucket force-destroy | yes | yes | **no** |
| Termination protection | off | off | **on** |
| Log retention | 7 d | 30 d | 90 d |
| Lambda memory / timeout | 128 MB / 30 s | 256 MB / 30 s | 512 MB / 60 s |

---

## Step 5 — Build the stack in stages (validate after each)

`-target` is normally a last-resort tool, but here it lets you apply one layer
at a time and inspect it. Run each plan, read it, then apply + validate.

**Stage 1 — Network**

```bash
terraform plan  -var-file=envs/localstack.tfvars -target=module.network
terraform apply -var-file=envs/localstack.tfvars -target=module.network
./scripts/validate.sh network localstack
# or: make stage-network
```

Manual check:

```bash
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
aws --endpoint-url http://localhost:4566 ec2 describe-subnets \
  --query 'Subnets[].[Tags[?Key==`Name`]|[0].Value,CidrBlock]' --output table
```

✅ Validate: 2 public + 2 private subnets, one NAT (dev), public RT → IGW, private RTs → NAT.

**Stage 2 — Storage**

```bash
terraform apply -var-file=envs/localstack.tfvars -target=module.storage
./scripts/validate.sh storage localstack
aws --endpoint-url http://localhost:4566 s3 ls
```

✅ Validate: bucket listed, `terraform output bucket_name` non-empty.

**Stage 3 — Async processing**

```bash
terraform apply -var-file=envs/localstack.tfvars -target=module.messaging
./scripts/validate.sh messaging localstack
./scripts/verify.sh
```

✅ Validate: `verify.sh` uploads under `uploads/` and you see `New upload: s3://...`.
Edit `modules/messaging/lambda_src/handler.py`, re-apply, watch only the function redeploy (zip hash changes).

**Stage 4 — Compute**

```bash
terraform apply -var-file=envs/localstack.tfvars -target=module.compute
./scripts/validate.sh compute localstack
aws --endpoint-url http://localhost:4566 ec2 describe-instances \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,PrivateIpAddress,State.Name]' --output table
```

✅ Validate: frontend + backend instances listed, `frontend_public_ip` output set.

**Stage 5 — Everything (also the normal day-to-day command)**

```bash
terraform plan  -var-file=envs/localstack.tfvars
terraform apply -var-file=envs/localstack.tfvars
terraform output
./scripts/validate.sh all localstack
```

✅ Validate: second `terraform plan` says *No changes* — code matches reality.

> **LocalStack reality check.** LocalStack simulates the EC2 *API*: instances,
> subnets and security groups exist, but `user_data` does not actually run, so nginx and Docker are
> not installed in LocalStack. You learn the Terraform and the wiring there; the install scripts
> (`modules/compute/templates/`) only really execute on real AWS. CloudFront is disabled in
> `envs/localstack.tfvars` because it was not in the free tier when this was written — check
> LocalStack's service coverage page and flip `enable_cloudfront` if your plan includes it.
> If EC2 fails with `InvalidAMIID`, list valid fake IDs and override:
> `aws --endpoint-url http://localhost:4566 ec2 describe-images --query 'Images[].ImageId' --output table`
> then `terraform plan -var-file=envs/localstack.tfvars -var='localstack_ami_id=ami-...'`.

---

## Step 6 — Experiment (this is where learning happens)

1. Change `az_count` for dev to 3 in `locals.tf`; run `plan`. How many resources change?
2. Add a tag to the S3 bucket in `modules/storage/main.tf`; run `plan` (an in-place update).
3. Change `max_receive_count`; apply; check `aws --endpoint-url http://localhost:4566 sqs get-queue-attributes --attribute-names RedrivePolicy`.
4. Delete the bucket from the LocalStack CLI, run `plan`. Terraform notices the drift.
5. Run `terraform fmt -recursive` and `terraform validate` before every commit.

---

## Step 7 — Staging and prod workspaces

```bash
terraform workspace select staging
terraform apply -var-file=envs/localstack.tfvars
./scripts/validate.sh all localstack
terraform output | head -20

terraform workspace select prod
terraform apply -var-file=envs/localstack.tfvars
./scripts/validate.sh all localstack

terraform workspace list
```

✅ Validate: `terraform output` differs per env (CIDRs, sizes in `locals.tf` table above).
State files sit under `terraform.tfstate.d/<workspace>/`.

---

## Step 8 — Tear down (per workspace)

```bash
terraform workspace select dev
terraform destroy -var-file=envs/localstack.tfvars
# repeat for staging/prod as needed
```

Prod has termination protection and a non-force-destroy bucket by design; to destroy it you must
deliberately turn those off first.

---

## Step 9 — Day-to-day habits

- `terraform fmt -recursive` and `terraform validate` before committing.
- Read every plan. Look for `destroy` and `replace` (`-/+`).
- One change at a time; commit `.terraform.lock.hcl`, never the state.

---

## Step 10 — Move to real AWS

1. Credentials: `aws configure sso` (or a named profile) — never hard-code keys.
2. Remote state: `cd bootstrap && terraform init && terraform apply -var="state_bucket_name=<unique>"`.
3. Replace `backend.tf` with `backend.s3.example` (edit the bucket name), then `terraform init -migrate-state`.
4. Create workspaces again (`terraform workspace select -or-create dev`).
5. `terraform plan -var-file=envs/aws.tfvars`, review, then apply **dev first**.
6. Open a shell on an instance without SSH: `aws ssm start-session --target <instance-id>`
   (needs the Session Manager plugin). Then check `docker ps`, `systemctl status nginx`, and
   `/var/log/cloud-init-output.log`.
7. Visit `terraform output app_url`, then `/api/` (proxied to the private backend).

Cost warning: NAT gateways bill hourly (prod has two). Destroy dev/staging when you are not using them.

---

## What is deliberately simple, and the production upgrade path

This keeps one instance per tier so you can read every line. For real production traffic:

| Today | Upgrade to |
|---|---|
| Single frontend/backend EC2 | Application Load Balancer + Auto Scaling Group across both AZs (launch template reusing the same user_data) |
| HTTP only | ACM certificate + HTTPS listener, CloudFront custom domain, Route 53 |
| nginx on the instance | WAF on CloudFront/ALB |
| Container `docker run` at boot | ECR image + a deploy pipeline (or move to ECS/Fargate) |
| No VPC flow logs | Flow logs to CloudWatch/S3, plus CloudTrail and GuardDuty |
| Secrets via env vars | SSM Parameter Store / Secrets Manager |
| No alarms | CloudWatch alarms on DLQ depth, Lambda errors, CPU, status checks |
| Manual apply | CI pipeline: `fmt`, `validate`, `plan` on PR, `apply` on merge, per-environment approvals |

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Error: Invalid provider configuration` / connection refused | LocalStack not running: `docker compose ps`; confirm `-var-file=envs/localstack.tfvars` |
| Port 4566 already in use | You already run `localstack-aws` — reuse it (`curl .../_localstack/health`), don't start a second container |
| `Workspace 'default' is not valid` | `terraform workspace select -or-create dev` |
| Lambda never runs on LocalStack | `docker logs localstack`; the Docker socket must be mounted (see `docker-compose.yml`) |
| S3 bucket name errors on AWS | Names are global; the random suffix handles this — re-run apply |
| `InvalidAMIID` on LocalStack | LocalStack's built-in AMI ids differ by version: `aws --endpoint-url http://localhost:4566 ec2 describe-images --query 'Images[].ImageId'` then `-var='localstack_ami_id=ami-...'` |
