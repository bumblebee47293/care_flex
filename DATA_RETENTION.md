# Data Retention and Compliance Policies

## Overview

CareFlex implements comprehensive data retention policies to ensure HIPAA compliance and proper data lifecycle management.

## Retention Periods

### Patient Records

- **Active Patients**: Retained indefinitely while account is active
- **Inactive Patients**: Soft-deleted after 2 years of inactivity
- **Hard Delete**: After 7 years from soft delete (HIPAA requirement)

### Appointments

- **Future Appointments**: Retained until completed or cancelled
- **Completed Appointments**: Retained for 7 years (HIPAA requirement)
- **Cancelled Appointments**: Retained for 3 years

### Benefits Data

- **Active Benefits**: Retained while period is valid
- **Expired Benefits**: Retained for 7 years for audit purposes
- **Usage History**: Retained for 7 years

### Audit Logs

- **All Audit Logs**: Retained for 7 years minimum (HIPAA requirement)
- **Immutable**: Never deleted, only archived
- **Archive Strategy**: Move to cold storage after 2 years

### Notifications

- **Delivery Logs**: Retained for 2 years
- **Message Content**: Retained for 1 year
- **Delivery Statistics**: Aggregated and retained indefinitely

## Soft Delete Implementation

All primary entities use soft deletes via `deleted_at` timestamp:

```elixir
# Patient soft delete
def delete_patient(patient, audit_context) do
  patient
  |> Patient.changeset(%{deleted_at: DateTime.utc_now()})
  |> Repo.update()
  |> log_audit(audit_context)
end

# Query excludes soft-deleted records
def list_patients do
  Patient
  |> where([p], is_nil(p.deleted_at))
  |> Repo.all()
end
```

## Hard Delete Process

Implemented via scheduled Oban worker:

```elixir
defmodule CareflexCore.Workers.DataRetentionWorker do
  use Oban.Worker, queue: :maintenance

  @impl Oban.Worker
  def perform(_job) do
    # Hard delete patients soft-deleted > 7 years ago
    cutoff_date = DateTime.utc_now() |> DateTime.add(-7 * 365, :day)

    Patient
    |> where([p], not is_nil(p.deleted_at))
    |> where([p], p.deleted_at < ^cutoff_date)
    |> Repo.delete_all()

    :ok
  end
end
```

## Archive Strategy

### Cold Storage Migration

After 2 years, move to archive tables:

1. **audit_logs** → **audit_logs_archive**
2. **appointments** → **appointments_archive**
3. **notifications** → **notifications_archive**

### Archive Process

```elixir
# Monthly archive job
defmodule CareflexCore.Workers.ArchiveWorker do
  use Oban.Worker, queue: :maintenance

  @impl Oban.Worker
  def perform(_job) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-2 * 365, :day)

    # Archive old audit logs
    AuditLog
    |> where([a], a.inserted_at < ^cutoff_date)
    |> Repo.all()
    |> Enum.each(&archive_audit_log/1)

    :ok
  end

  defp archive_audit_log(log) do
    # Insert into archive table
    # Delete from main table
  end
end
```

## Compliance Requirements

### HIPAA Requirements

1. **Minimum Retention**: 7 years from last patient interaction
2. **Audit Trails**: Complete audit logs for all PHI access
3. **Secure Deletion**: Cryptographic erasure of encryption keys
4. **Backup Retention**: Encrypted backups retained for 7 years

### Implementation

```elixir
# Secure deletion by rotating encryption keys
defmodule CareflexCore.Vault do
  def secure_delete_patient(patient_id) do
    # 1. Soft delete patient
    # 2. Generate new encryption key
    # 3. Re-encrypt all other patients
    # 4. Destroy old key (makes old data unrecoverable)
  end
end
```

## Automated Cleanup Jobs

### Daily Jobs

- Expire old benefits
- Mark no-show appointments
- Update appointment statuses

### Weekly Jobs

- Clean up old notifications (> 2 years)
- Archive completed appointments (> 2 years)

### Monthly Jobs

- Archive audit logs (> 2 years)
- Generate retention compliance reports

### Annual Jobs

- Hard delete soft-deleted patients (> 7 years)
- Purge archived data (> 7 years)

## Monitoring and Reporting

### Retention Metrics

Track via dashboard:

- Records pending deletion
- Archive table sizes
- Compliance status
- Deletion job success rates

### Compliance Reports

Monthly reports include:

- Total records by retention status
- Deletion audit trail
- Archive statistics
- Policy compliance score

## Configuration

```elixir
# config/config.exs
config :careflex_core, :retention_policies,
  patient_inactive_period: 2 * 365,  # 2 years
  hard_delete_period: 7 * 365,       # 7 years
  archive_period: 2 * 365,           # 2 years
  notification_retention: 2 * 365,   # 2 years
  audit_log_archive: 2 * 365         # 2 years
```

## Emergency Data Deletion

For legal right-to-be-forgotten requests:

```elixir
defmodule CareflexCore.Care do
  def emergency_delete_patient(patient_id, legal_request_id) do
    Repo.transaction(fn ->
      # 1. Log legal request
      # 2. Export data for compliance
      # 3. Hard delete all patient data
      # 4. Destroy encryption keys
      # 5. Create deletion certificate
    end)
  end
end
```

## Best Practices

1. **Never hard delete immediately** - Always soft delete first
2. **Maintain audit trail** - Log all deletion operations
3. **Encrypt backups** - All archived data must be encrypted
4. **Regular reviews** - Quarterly review of retention policies
5. **Compliance testing** - Annual audit of retention compliance

---

_This policy ensures HIPAA compliance while maintaining operational efficiency and data security._
