# Terraform Deployment Guide

This directory contains Terraform configuration for deploying CareFlex to Fly.io.

## Prerequisites

1. **Install Terraform**: https://www.terraform.io/downloads
2. **Install Fly CLI**: https://fly.io/docs/hands-on/install-flyctl/
3. **Fly.io Account**: Sign up at https://fly.io/
4. **Fly API Token**: Run `fly auth token` to get your token

## Setup

### 1. Configure Environment

```bash
# Set Fly.io API token
export FLY_API_TOKEN=$(fly auth token)
```

### 2. Generate Secrets

```bash
# Generate Phoenix secret key base
mix phx.gen.secret

# Generate Cloak encryption key
openssl rand -base64 32

# Generate Guardian JWT secret
mix phx.gen.secret
```

### 3. Configure Variables

```bash
# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# IMPORTANT: Never commit terraform.tfvars to git!
```

## Deployment

### Initialize Terraform

```bash
cd terraform
terraform init
```

### Plan Deployment

```bash
terraform plan
```

Review the planned changes carefully.

### Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### Verify Deployment

```bash
# Check application status
fly status -a careflex

# View logs
fly logs -a careflex

# Open application
fly open -a careflex
```

## Post-Deployment

### Run Migrations

```bash
fly ssh console -a careflex
/app/bin/careflex eval "CareflexCore.Release.migrate"
```

### Seed Database (Optional)

```bash
fly ssh console -a careflex
/app/bin/careflex eval "CareflexCore.Release.seed"
```

## Updating Infrastructure

```bash
# Make changes to .tf files
# Plan changes
terraform plan

# Apply changes
terraform apply
```

## Scaling

### Vertical Scaling (VM Size)

Edit `main.tf` and change `vm_size` in the database resource, then apply:

```bash
terraform apply
```

### Horizontal Scaling (Instances)

```bash
fly scale count 2 -a careflex
```

## Monitoring

### View Metrics

```bash
fly dashboard -a careflex
```

### Check Database

```bash
fly postgres connect -a careflex-db
```

## Destroying Infrastructure

**WARNING**: This will delete all resources and data!

```bash
terraform destroy
```

## Troubleshooting

### State Lock Issues

```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### Secret Updates

```bash
# Update secrets via Fly CLI
fly secrets set SECRET_KEY_BASE=new-value -a careflex

# Or update via Terraform
# Edit terraform.tfvars and run:
terraform apply
```

### Database Connection Issues

```bash
# Check database status
fly postgres db list -a careflex-db

# View database logs
fly logs -a careflex-db
```

## Security Best Practices

1. **Never commit** `terraform.tfvars` or `*.tfstate` files
2. **Use environment variables** for sensitive data in CI/CD
3. **Enable 2FA** on your Fly.io account
4. **Rotate secrets** regularly
5. **Use separate workspaces** for staging/production

## Resources

- [Fly.io Documentation](https://fly.io/docs/)
- [Terraform Fly Provider](https://registry.terraform.io/providers/fly-apps/fly/latest/docs)
- [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)
