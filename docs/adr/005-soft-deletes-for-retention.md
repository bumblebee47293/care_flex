# ADR 005: Use Soft Deletes for Data Retention

## Status

Accepted

## Context

Healthcare regulations (HIPAA) require:

- Maintaining patient records for minimum 7 years
- Audit trail of all data changes
- Ability to recover "deleted" data
- Compliance with right-to-be-forgotten requests

We need a deletion strategy that balances:

- User experience (deleted items don't appear)
- Compliance (data retained for required period)
- Performance (queries remain fast)

## Decision

We will implement soft deletes using a `deleted_at` timestamp field on all primary entities.

## Consequences

### Positive

- **Compliance**: Meets HIPAA retention requirements
- **Recoverability**: Can restore accidentally deleted data
- **Audit Trail**: Maintains complete history
- **Gradual Cleanup**: Can hard delete after retention period
- **Simple Implementation**: Just add timestamp field

### Negative

- **Query Complexity**: Must filter out deleted records in all queries
- **Index Overhead**: Need indexes on deleted_at
- **Storage Cost**: Deleted data still consumes space
- **Confusion**: Developers must remember to filter deleted records

## Implementation Details

```elixir
# Schema
schema "patients" do
  # ... fields ...
  field :deleted_at, :utc_datetime
  timestamps()
end

# Queries automatically exclude deleted
def list_patients do
  Patient
  |> where([p], is_nil(p.deleted_at))
  |> Repo.all()
end

# Soft delete
def delete_patient(patient, audit_context) do
  patient
  |> Patient.changeset(%{deleted_at: DateTime.utc_now()})
  |> Repo.update()
  |> log_audit(audit_context)
end
```

## Hard Delete Strategy

- Automated job runs annually
- Hard deletes records where `deleted_at > 7 years ago`
- Requires legal approval for early deletion
- Cryptographic key destruction for secure deletion

## Alternatives Considered

1. **Hard Delete**: Doesn't meet compliance requirements
2. **Archive Tables**: More complex, harder to query
3. **Event Sourcing**: Overkill for current needs
4. **Separate Archive Database**: Additional infrastructure

## Migration Path

- Add `deleted_at` column to existing tables
- Update all queries to filter deleted records
- Create indexes on `deleted_at`
- Implement hard delete worker

## Notes

- Soft deletes are industry standard for healthcare applications
- Ecto makes it easy to scope queries
- Can use Ecto.SoftDelete library for automation
- Must document retention policy clearly
