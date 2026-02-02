# Production Secrets Management Guide

This guide covers best practices for managing secrets in production environments.

## Secret Types

CareFlex requires the following secrets:

### Application Secrets

- `SECRET_KEY_BASE` - Phoenix session encryption
- `GUARDIAN_SECRET_KEY` - JWT token signing
- `CLOAK_KEY` - PII field encryption

### Database

- `DATABASE_URL` - PostgreSQL connection string

### External APIs (Optional)

- `BENEFITS_API_KEY` - Insurance benefits API
- `BENEFITS_API_URL` - Benefits API endpoint
- `PROVIDER_API_KEY` - Care provider API
- `PROVIDER_API_URL` - Provider API endpoint

### Monitoring (Optional)

- `APPSIGNAL_PUSH_API_KEY` - AppSignal monitoring
- `SENTRY_DSN` - Error tracking

## Generating Secrets

### Phoenix Secret Key Base

```bash
mix phx.gen.secret
```

### Cloak Encryption Key

```bash
# Generate 32-byte base64 encoded key
openssl rand -base64 32
```

### Guardian JWT Secret

```bash
mix phx.gen.secret
```

## Storage Options

### 1. Fly.io Secrets (Recommended for Fly.io)

```bash
# Set individual secrets
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret) -a careflex
fly secrets set CLOAK_KEY=$(openssl rand -base64 32) -a careflex
fly secrets set GUARDIAN_SECRET_KEY=$(mix phx.gen.secret) -a careflex

# Set from file
fly secrets import < secrets.txt -a careflex

# List secrets (values are hidden)
fly secrets list -a careflex

# Remove secret
fly secrets unset SECRET_NAME -a careflex
```

### 2. Environment Variables (Heroku)

```bash
# Set secrets
heroku config:set SECRET_KEY_BASE=$(mix phx.gen.secret)
heroku config:set CLOAK_KEY=$(openssl rand -base64 32)
heroku config:set GUARDIAN_SECRET_KEY=$(mix phx.gen.secret)

# View secrets
heroku config

# Remove secret
heroku config:unset SECRET_NAME
```

### 3. AWS Secrets Manager

```bash
# Install AWS CLI
aws configure

# Create secret
aws secretsmanager create-secret \
  --name careflex/production/secret-key-base \
  --secret-string $(mix phx.gen.secret)

# Retrieve secret
aws secretsmanager get-secret-value \
  --secret-id careflex/production/secret-key-base \
  --query SecretString \
  --output text
```

### 4. HashiCorp Vault

```bash
# Write secret
vault kv put secret/careflex/production \
  secret_key_base=$(mix phx.gen.secret) \
  cloak_key=$(openssl rand -base64 32)

# Read secret
vault kv get secret/careflex/production
```

### 5. Kubernetes Secrets

```yaml
# secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: careflex-secrets
type: Opaque
stringData:
  SECRET_KEY_BASE: "your-secret-here"
  CLOAK_KEY: "your-cloak-key-here"
  GUARDIAN_SECRET_KEY: "your-guardian-secret-here"
```

```bash
# Apply secrets
kubectl apply -f secrets.yaml

# View secrets
kubectl get secrets careflex-secrets -o yaml
```

## Local Development

### .env File (DO NOT COMMIT)

Create `.env` file:

```bash
export SECRET_KEY_BASE="dev-secret-key-base"
export CLOAK_KEY="dev-cloak-key"
export GUARDIAN_SECRET_KEY="dev-guardian-secret"
export DATABASE_URL="ecto://postgres:postgres@localhost/careflex_dev"
```

Load environment:

```bash
source .env
```

### direnv (Recommended)

Install direnv: https://direnv.net/

Create `.envrc`:

```bash
export SECRET_KEY_BASE="dev-secret-key-base"
export CLOAK_KEY="dev-cloak-key"
export GUARDIAN_SECRET_KEY="dev-guardian-secret"
```

Allow direnv:

```bash
direnv allow
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/deploy.yml
env:
  SECRET_KEY_BASE: ${{ secrets.SECRET_KEY_BASE }}
  CLOAK_KEY: ${{ secrets.CLOAK_KEY }}
  GUARDIAN_SECRET_KEY: ${{ secrets.GUARDIAN_SECRET_KEY }}
```

Add secrets in GitHub:

1. Go to repository Settings > Secrets and variables > Actions
2. Click "New repository secret"
3. Add each secret

### GitLab CI

```yaml
# .gitlab-ci.yml
variables:
  SECRET_KEY_BASE: $SECRET_KEY_BASE
  CLOAK_KEY: $CLOAK_KEY
```

Add secrets in GitLab:

1. Go to Settings > CI/CD > Variables
2. Add each secret with "Masked" and "Protected" flags

## Security Best Practices

### 1. Never Commit Secrets

Add to `.gitignore`:

```
.env
.envrc
secrets.txt
terraform.tfvars
*.secret
```

### 2. Rotate Secrets Regularly

```bash
# Generate new secret
NEW_SECRET=$(mix phx.gen.secret)

# Update in production
fly secrets set SECRET_KEY_BASE=$NEW_SECRET -a careflex

# Restart application
fly apps restart careflex
```

### 3. Use Different Secrets Per Environment

- Development: Simple, non-sensitive
- Staging: Production-like, rotated monthly
- Production: Strong, rotated quarterly

### 4. Audit Secret Access

```bash
# Fly.io audit log
fly logs -a careflex | grep "secret"

# AWS CloudTrail
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=careflex
```

### 5. Encrypt Secrets at Rest

- Use encrypted storage (AWS Secrets Manager, Vault)
- Enable encryption on Kubernetes secrets
- Use encrypted environment variables

### 6. Limit Secret Scope

- Use least privilege principle
- Separate secrets by service
- Use service accounts with limited permissions

## Emergency Procedures

### Secret Compromise

1. **Immediately rotate** the compromised secret
2. **Audit logs** to identify unauthorized access
3. **Notify team** and stakeholders
4. **Update documentation** with incident details

### Lost Secrets

1. **Generate new secrets** using the commands above
2. **Update all environments** (dev, staging, production)
3. **Test thoroughly** before deploying to production
4. **Document** the recovery process

## Monitoring

### Secret Expiration Alerts

Set up alerts for:

- Secrets older than 90 days
- Failed secret access attempts
- Unauthorized secret modifications

### Health Checks

```bash
# Test database connection
fly ssh console -a careflex -C "bin/careflex rpc 'CareflexCore.Repo.query!(\"SELECT 1\")'"

# Test encryption
fly ssh console -a careflex -C "bin/careflex rpc 'CareflexCore.Vault.encrypt!(\"test\")'"
```

## Resources

- [Fly.io Secrets Documentation](https://fly.io/docs/reference/secrets/)
- [12-Factor App: Config](https://12factor.net/config)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
