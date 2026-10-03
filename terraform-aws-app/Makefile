# Shortcuts so you do not have to remember the flags.
#   make init
#   make workspaces            # create dev/staging/prod (local state, no AWS calls)
#   make plan  ENV=dev
#   make apply ENV=staging
#   make apply ENV=prod TARGET=aws
# Every command is also shown in full in README.md.
.RECIPEPREFIX := >
ENV    ?= dev
TARGET ?= localstack
VARS   := -var-file=envs/$(TARGET).tfvars

.PHONY: init workspace workspaces fmt validate plan apply destroy output localstack-up localstack-down localstack-health verify validate-all stage-network stage-storage stage-messaging stage-compute

init:
> terraform init

workspace:
> terraform workspace select -or-create $(ENV)

# Create dev/staging/prod workspaces up front (safe: local state only).
workspaces: init
> terraform workspace select -or-create dev
> terraform workspace select -or-create staging
> terraform workspace select -or-create prod
> terraform workspace select dev
> terraform workspace list

fmt:
> terraform fmt -recursive

validate: init
> terraform validate

# Full local validation: fmt check + validate + plan (no changes applied).
validate-all: fmt validate
> terraform validate
> terraform workspace select -or-create $(ENV)
> terraform plan $(VARS) -detailed-exitcode; test $$? -eq 0 -o $$? -eq 2

plan: workspace
> terraform plan $(VARS)

apply: workspace
> terraform apply $(VARS)

destroy: workspace
> terraform destroy $(VARS)

output: workspace
> terraform output

# Staged applies for learning (see README Step 5). Each ends with a validate step.
stage-network: workspace
> terraform plan $(VARS) -target=module.network
> terraform apply $(VARS) -target=module.network
> ./scripts/validate.sh network $(TARGET)

stage-storage: workspace
> terraform apply $(VARS) -target=module.storage
> ./scripts/validate.sh storage $(TARGET)

stage-messaging: workspace
> terraform apply $(VARS) -target=module.messaging
> ./scripts/validate.sh messaging $(TARGET)

stage-compute: workspace
> terraform apply $(VARS) -target=module.compute
> ./scripts/validate.sh compute $(TARGET)

localstack-up:
> docker compose up -d

localstack-down:
> docker compose down

localstack-health:
> curl -s http://localhost:4566/_localstack/health | head -c 400; echo

verify:
> ./scripts/verify.sh
