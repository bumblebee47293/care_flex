# ADR 004: Use Oban for Background Job Processing

## Status

Accepted

## Context

The application requires background processing for:

- Appointment reminders (24h and 2h before)
- Daily no-show risk calculation
- External benefits API synchronization
- Future: email campaigns, report generation

Requirements:

- Reliable job execution
- Retry logic with exponential backoff
- Scheduled/cron jobs
- Job monitoring and observability
- Database-backed (no Redis dependency)

## Decision

We will use Oban for all background job processing.

## Consequences

### Positive

- **PostgreSQL-Backed**: Uses existing database, no additional infrastructure
- **Reliable**: ACID guarantees for job persistence
- **Feature-Rich**: Cron, retries, priorities, dead letter queue
- **Observability**: Built-in job metrics and monitoring
- **Distributed**: Works across multiple nodes
- **Type-Safe**: Compile-time job validation

### Negative

- **Database Load**: Jobs stored in PostgreSQL (not an issue at current scale)
- **Learning Curve**: Team needs to learn Oban patterns
- **Cost**: Pro features require license (not needed currently)

## Implementation Details

```elixir
# Worker example
defmodule CareflexCore.Workers.ReminderWorker do
  use Oban.Worker,
    queue: :events,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"appointment_id" => id}}) do
    # Send reminder
  end
end

# Scheduling
%{appointment_id: appt.id}
|> ReminderWorker.new(scheduled_at: reminder_time)
|> Oban.insert()
```

## Alternatives Considered

1. **Sidekiq/Resque (via Exq)**: Requires Redis, less Elixir-native
2. **GenServer-based**: No persistence, loses jobs on restart
3. **Quantum**: Good for cron but not general job processing
4. **Custom Solution**: Reinventing the wheel

## Queue Configuration

- `default`: General background tasks (10 workers)
- `events`: Time-sensitive tasks like reminders (50 workers)
- `mailers`: Email sending (20 workers)
- `maintenance`: Low-priority cleanup (5 workers)

## Notes

- Oban is the de facto standard for Elixir background jobs
- Active development and excellent documentation
- Can add Oban Pro later for advanced features (batching, workflows)
- Works seamlessly with Ecto and Phoenix
