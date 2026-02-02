# CareFlex Deployment Guide

## Prerequisites

Before deploying CareFlex, ensure you have:

- Elixir 1.15+ and OTP 26.0+ installed
- PostgreSQL 15+ database
- Git repository access
- Deployment platform account (Fly.io, Heroku, or AWS)

## Environment Variables

### Required Variables

```bash
# Database
DATABASE_URL=postgresql://user:pass@host:5432/careflex_prod

# Phoenix
SECRET_KEY_BASE=<generate with: mix phx.gen.secret>
PHX_HOST=your-app.fly.dev

# Encryption
CLOAK_KEY=<generate with: mix guardian.gen.secret>

# Oban
OBAN_QUEUES=default:10,mailers:20,events:50,media:5
```

### Optional Variables

```bash
# External APIs (if using real integrations)
BENEFITS_API_URL=https://api.insurance-provider.com
BENEFITS_API_KEY=your_api_key

PROVIDER_API_URL=https://api.care-provider.com
PROVIDER_API_KEY=your_api_key

# Monitoring
APPSIGNAL_PUSH_API_KEY=your_key
```

## Deployment Options

### Option 1: Fly.io (Recommended)

#### 1. Install Fly CLI

```bash
# macOS
brew install flyctl

# Linux
curl -L https://fly.io/install.sh | sh

# Windows
pwsh -Command "iwr https://fly.io/install.ps1 -useb | iex"
```

#### 2. Login and Initialize

```bash
fly auth login
cd care_flex
fly launch
```

#### 3. Configure Secrets

```bash
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
fly secrets set CLOAK_KEY=$(mix phx.gen.secret)
fly secrets set DATABASE_URL=<your-postgres-url>
```

#### 4. Create PostgreSQL Database

```bash
fly postgres create
fly postgres attach <postgres-app-name>
```

#### 5. Deploy

```bash
fly deploy
```

#### 6. Run Migrations

```bash
fly ssh console
/app/bin/careflex eval "CareflexCore.Release.migrate"
```

#### 7. Seed Database (Optional)

```bash
fly ssh console
/app/bin/careflex eval "CareflexCore.Release.seed"
```

### Option 2: Heroku

#### 1. Install Heroku CLI

```bash
# macOS
brew tap heroku/brew && brew install heroku

# Other platforms
# Download from https://devcenter.heroku.com/articles/heroku-cli
```

#### 2. Create App

```bash
heroku create careflex-prod
heroku addons:create heroku-postgresql:standard-0
```

#### 3. Configure Buildpacks

```bash
heroku buildpacks:add hashnuke/elixir
heroku buildpacks:add https://github.com/gjaldon/heroku-buildpack-phoenix-static
```

#### 4. Set Environment Variables

```bash
heroku config:set SECRET_KEY_BASE=$(mix phx.gen.secret)
heroku config:set CLOAK_KEY=$(mix phx.gen.secret)
heroku config:set POOL_SIZE=18
```

#### 5. Deploy

```bash
git push heroku main
```

#### 6. Run Migrations

```bash
heroku run "/app/bin/careflex eval 'CareflexCore.Release.migrate'"
```

### Option 3: AWS (ECS/Fargate)

#### 1. Build Docker Image

```dockerfile
# Dockerfile
FROM hexpm/elixir:1.15.7-erlang-26.1.2-alpine-3.18.4 AS build

# Install build dependencies
RUN apk add --no-cache build-base git

# Prepare build directory
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application files
COPY apps apps
COPY priv priv

# Compile and build release
RUN mix compile
RUN mix release

# Prepare release image
FROM alpine:3.18.4 AS app

RUN apk add --no-cache openssl ncurses-libs libstdc++

WORKDIR /app

RUN chown nobody:nobody /app

USER nobody:nobody

COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/careflex ./

ENV HOME=/app

CMD ["bin/careflex", "start"]
```

#### 2. Build and Push

```bash
docker build -t careflex:latest .
docker tag careflex:latest <your-ecr-repo>:latest
docker push <your-ecr-repo>:latest
```

#### 3. Create ECS Task Definition

```json
{
  "family": "careflex",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "containerDefinitions": [
    {
      "name": "careflex",
      "image": "<your-ecr-repo>:latest",
      "portMappings": [
        {
          "containerPort": 4000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "PHX_HOST",
          "value": "your-domain.com"
        }
      ],
      "secrets": [
        {
          "name": "SECRET_KEY_BASE",
          "valueFrom": "arn:aws:secretsmanager:..."
        },
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:..."
        }
      ]
    }
  ]
}
```

## Database Migrations

### Create Release Module

```elixir
# lib/careflex_core/release.ex
defmodule CareflexCore.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix.
  """
  @app :careflex_core

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn _repo ->
        Code.eval_file("priv/repo/seeds.exs")
      end)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
```

### Run Migrations in Production

```bash
# Fly.io
fly ssh console -C "/app/bin/careflex eval 'CareflexCore.Release.migrate'"

# Heroku
heroku run "/app/bin/careflex eval 'CareflexCore.Release.migrate'"

# Docker
docker exec -it careflex bin/careflex eval "CareflexCore.Release.migrate"
```

## Health Checks

Add health check endpoint:

```elixir
# lib/careflex_web/controllers/health_controller.ex
defmodule CareflexWeb.HealthController do
  use CareflexWeb, :controller

  def index(conn, _params) do
    # Check database
    case Ecto.Adapters.SQL.query(CareflexCore.Repo, "SELECT 1") do
      {:ok, _} ->
        json(conn, %{status: "healthy", database: "connected"})
      {:error, _} ->
        conn
        |> put_status(503)
        |> json(%{status: "unhealthy", database: "disconnected"})
    end
  end
end
```

## Monitoring Setup

### Application Monitoring

```elixir
# config/prod.exs
config :careflex_core, :appsignal,
  active: true,
  name: "CareFlex",
  push_api_key: System.get_env("APPSIGNAL_PUSH_API_KEY")
```

### Log Aggregation

```elixir
# config/prod.exs
config :logger,
  backends: [:console, LoggerJSON],
  level: :info

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]
```

## SSL/TLS Configuration

### Fly.io (Automatic)

```bash
fly certs add your-domain.com
```

### Manual Certificate

```elixir
# config/prod.exs
config :careflex_web, CareflexWeb.Endpoint,
  https: [
    port: 443,
    cipher_suite: :strong,
    keyfile: System.get_env("SSL_KEY_PATH"),
    certfile: System.get_env("SSL_CERT_PATH")
  ]
```

## Scaling

### Horizontal Scaling

```bash
# Fly.io
fly scale count 3

# Heroku
heroku ps:scale web=3
```

### Vertical Scaling

```bash
# Fly.io
fly scale vm shared-cpu-2x

# Heroku
heroku ps:resize web=standard-2x
```

## Backup Strategy

### Database Backups

```bash
# Fly.io Postgres
fly postgres backup create

# Heroku
heroku pg:backups:capture
heroku pg:backups:download
```

### Automated Backups

```bash
# Fly.io (automatic daily backups)
# Heroku (configure via dashboard)
```

## Rollback Procedure

### Fly.io

```bash
# List releases
fly releases

# Rollback to previous
fly releases rollback <version>
```

### Heroku

```bash
# List releases
heroku releases

# Rollback
heroku rollback v<number>
```

## Troubleshooting

### Check Logs

```bash
# Fly.io
fly logs

# Heroku
heroku logs --tail

# Docker
docker logs -f careflex
```

### Connect to Console

```bash
# Fly.io
fly ssh console
/app/bin/careflex remote

# Heroku
heroku run iex -S mix

# Docker
docker exec -it careflex /app/bin/careflex remote
```

### Database Console

```bash
# Fly.io
fly postgres connect -a <postgres-app>

# Heroku
heroku pg:psql
```

## Performance Tuning

### Database Connection Pool

```elixir
# config/prod.exs
config :careflex_core, CareflexCore.Repo,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
```

### Oban Configuration

```elixir
# config/prod.exs
config :careflex_core, Oban,
  repo: CareflexCore.Repo,
  queues: [
    default: 10,
    mailers: 20,
    events: 50,
    media: 5
  ]
```

## Security Checklist

- [ ] Set strong SECRET_KEY_BASE
- [ ] Enable HTTPS only
- [ ] Configure CORS properly
- [ ] Set secure cookie flags
- [ ] Enable rate limiting
- [ ] Configure firewall rules
- [ ] Rotate encryption keys regularly
- [ ] Enable audit logging
- [ ] Set up intrusion detection
- [ ] Regular security scans

## Post-Deployment

1. **Verify deployment**: Check health endpoint
2. **Run smoke tests**: Test critical user flows
3. **Monitor logs**: Watch for errors
4. **Check metrics**: CPU, memory, response times
5. **Verify background jobs**: Ensure Oban is processing
6. **Test real-time features**: Check WebSocket connections

---

_For production support, refer to ARCHITECTURE.md and project documentation._
