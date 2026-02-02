# Monitoring and Alerting Guide

This guide covers monitoring, logging, and alerting setup for CareFlex in production.

## Monitoring Stack

### Recommended Tools

1. **Application Monitoring**: AppSignal or New Relic
2. **Error Tracking**: Sentry
3. **Logging**: Fly.io Logs or Papertrail
4. **Uptime Monitoring**: UptimeRobot or Pingdom
5. **Database Monitoring**: Built-in Fly.io Postgres metrics

## Application Monitoring

### AppSignal Setup

1. **Install AppSignal**

Add to `mix.exs`:

```elixir
{:appsignal_phoenix, "~> 2.3"}
```

2. **Configure AppSignal**

```elixir
# config/prod.exs
config :appsignal, :config,
  otp_app: :careflex_web,
  name: "CareFlex",
  push_api_key: System.get_env("APPSIGNAL_PUSH_API_KEY"),
  env: :prod,
  active: true
```

3. **Add to Application**

```elixir
# lib/careflex_web/endpoint.ex
plug Appsignal.Phoenix
```

4. **Set Secret**

```bash
fly secrets set APPSIGNAL_PUSH_API_KEY=your-key -a careflex
```

### Key Metrics to Monitor

- **Response Time**: P50, P95, P99
- **Throughput**: Requests per minute
- **Error Rate**: 4xx and 5xx responses
- **Database Queries**: Query time, N+1 queries
- **Background Jobs**: Queue size, processing time
- **Memory Usage**: Heap size, process count
- **CPU Usage**: Utilization percentage

## Error Tracking

### Sentry Setup

1. **Install Sentry**

```elixir
# mix.exs
{:sentry, "~> 10.0"}
```

2. **Configure Sentry**

```elixir
# config/prod.exs
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: :prod,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  tags: %{
    env: "production"
  },
  included_environments: [:prod]
```

3. **Add Logger Backend**

```elixir
# config/prod.exs
config :logger,
  backends: [:console, Sentry.LoggerBackend]
```

4. **Set Secret**

```bash
fly secrets set SENTRY_DSN=your-dsn -a careflex
```

### Error Grouping

Configure Sentry to group errors by:

- Error type
- Stack trace fingerprint
- User context (role, ID)
- Request path

## Logging

### Structured Logging

```elixir
# lib/careflex_core/application.ex
def start(_type, _args) do
  # Configure JSON logging for production
  if Application.get_env(:careflex_core, :env) == :prod do
    :logger.add_handler(:json_handler, :logger_std_h, %{
      formatter: {Jason.Formatter, %{}}
    })
  end

  # ... rest of application start
end
```

### Log Levels

```elixir
# config/prod.exs
config :logger,
  level: :info,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]
```

### Important Events to Log

- User authentication (login, logout, failed attempts)
- Appointment scheduling/cancellation
- Benefits usage
- PII access (with audit trail)
- Background job execution
- External API calls
- Database migrations
- Application errors

### Fly.io Logs

```bash
# View live logs
fly logs -a careflex

# Filter by level
fly logs -a careflex | grep "level=error"

# Export logs
fly logs -a careflex > logs.txt
```

### Papertrail Integration

```bash
# Add Papertrail drain
fly secrets set PAPERTRAIL_URL=your-papertrail-url -a careflex
```

## Uptime Monitoring

### UptimeRobot Setup

1. Create account at https://uptimerobot.com
2. Add HTTP(s) monitor for `https://careflex.fly.dev`
3. Configure alerts:
   - Email notifications
   - Slack integration
   - SMS for critical alerts

### Health Check Endpoint

```elixir
# lib/careflex_web/controllers/health_controller.ex
defmodule CareflexWeb.HealthController do
  use CareflexWeb, :controller

  def check(conn, _params) do
    # Check database
    case CareflexCore.Repo.query("SELECT 1") do
      {:ok, _} ->
        json(conn, %{status: "healthy", timestamp: DateTime.utc_now()})

      {:error, _} ->
        conn
        |> put_status(503)
        |> json(%{status: "unhealthy", reason: "database_unavailable"})
    end
  end
end
```

```elixir
# lib/careflex_web/router.ex
scope "/api" do
  get "/health", HealthController, :check
end
```

## Database Monitoring

### Fly.io Postgres Metrics

```bash
# View database metrics
fly postgres db list -a careflex-db

# Check replication status
fly postgres db show -a careflex-db

# View slow queries
fly ssh console -a careflex-db
psql -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"
```

### Query Performance

Monitor:

- Slow queries (> 1 second)
- Connection pool usage
- Lock wait time
- Index usage
- Table bloat

## Alerting Rules

### Critical Alerts (Immediate Response)

- Application down (> 5 minutes)
- Database unavailable
- Error rate > 5%
- Response time P95 > 5 seconds
- Disk usage > 90%
- Memory usage > 90%

### Warning Alerts (Review Within 1 Hour)

- Error rate > 1%
- Response time P95 > 2 seconds
- Background job queue > 1000
- Failed login attempts > 100/hour
- Disk usage > 75%

### Info Alerts (Daily Review)

- New user registrations
- Appointment volume trends
- Benefits usage patterns
- API rate limit warnings

## Alert Channels

### Slack Integration

```bash
# AppSignal Slack webhook
# Configure in AppSignal dashboard

# Sentry Slack integration
# Configure in Sentry project settings
```

### PagerDuty (For Critical Alerts)

1. Create PagerDuty account
2. Add integration in AppSignal/Sentry
3. Configure escalation policies
4. Set up on-call schedules

### Email Alerts

Configure in monitoring tools:

- Development team for errors
- DevOps team for infrastructure
- Management for business metrics

## Dashboards

### AppSignal Dashboard

Monitor:

- Request throughput
- Response times
- Error rates
- Background jobs
- Custom metrics

### Fly.io Dashboard

```bash
fly dashboard -a careflex
```

Monitor:

- Instance health
- Resource usage
- Deployment history
- Metrics graphs

### Custom Grafana Dashboard (Advanced)

```yaml
# docker-compose.yml for local Grafana
version: "3"
services:
  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana

volumes:
  grafana-data:
```

## Performance Budgets

Set performance budgets:

- Homepage load time: < 2 seconds
- API response time P95: < 500ms
- GraphQL query time P95: < 1 second
- Background job processing: < 5 seconds
- Database query time P95: < 100ms

## Incident Response

### Runbook Template

```markdown
# Incident: [Title]

## Severity

- [ ] Critical (P1)
- [ ] High (P2)
- [ ] Medium (P3)
- [ ] Low (P4)

## Impact

- Affected users:
- Affected features:
- Data loss risk:

## Timeline

- Detected:
- Acknowledged:
- Mitigated:
- Resolved:

## Root Cause

[Description]

## Resolution

[Steps taken]

## Prevention

[Future improvements]
```

### Common Issues

#### High Error Rate

```bash
# Check recent errors
fly logs -a careflex | grep "error"

# Check Sentry for patterns
# Review recent deployments
fly releases -a careflex

# Rollback if needed
fly releases rollback -a careflex
```

#### Slow Response Times

```bash
# Check resource usage
fly status -a careflex

# Scale up if needed
fly scale vm shared-cpu-2x -a careflex
fly scale count 2 -a careflex

# Check database
fly postgres db show -a careflex-db
```

#### Database Issues

```bash
# Check connections
fly ssh console -a careflex-db
psql -c "SELECT count(*) FROM pg_stat_activity;"

# Check slow queries
psql -c "SELECT * FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"

# Restart if needed
fly postgres restart -a careflex-db
```

## Monitoring Checklist

- [ ] Application monitoring configured
- [ ] Error tracking enabled
- [ ] Structured logging implemented
- [ ] Uptime monitoring active
- [ ] Database metrics tracked
- [ ] Alert rules defined
- [ ] Notification channels configured
- [ ] Dashboards created
- [ ] Performance budgets set
- [ ] Incident runbooks documented
- [ ] On-call schedule established
- [ ] Regular review process defined

## Resources

- [AppSignal Elixir Documentation](https://docs.appsignal.com/elixir/)
- [Sentry Elixir SDK](https://docs.sentry.io/platforms/elixir/)
- [Fly.io Monitoring](https://fly.io/docs/reference/metrics/)
- [Phoenix Telemetry](https://hexdocs.pm/phoenix/telemetry.html)
