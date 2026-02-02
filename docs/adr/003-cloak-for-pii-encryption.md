# ADR 003: Use Cloak for PII Encryption

## Status

Accepted

## Context

Healthcare applications must protect Personally Identifiable Information (PII) to comply with HIPAA regulations. We need to encrypt:

- Patient names
- Email addresses
- Phone numbers
- Dates of birth

Requirements:

- Encryption at rest in the database
- Transparent encryption/decryption in application code
- Ability to search encrypted fields (for emails)
- Key rotation capability

## Decision

We will use Cloak Ecto for field-level encryption with AES-256-GCM cipher.

## Consequences

### Positive

- **HIPAA Compliance**: Meets encryption at rest requirements
- **Transparent**: Automatic encryption/decryption via Ecto
- **Field-Level**: Only encrypts sensitive fields, not entire database
- **Performance**: Minimal overhead for encryption operations
- **Searchable**: Can hash emails for lookups while keeping data encrypted

### Negative

- **Key Management**: Must securely manage encryption keys
- **Migration Complexity**: Encrypting existing data requires careful migration
- **Search Limitations**: Can't do partial searches on encrypted fields
- **Backup Considerations**: Backups must also protect encryption keys

## Implementation Details

```elixir
defmodule CareflexCore.Vault do
  use Cloak.Vault, otp_app: :careflex_core
end

# In Patient schema
field :email, CareflexCore.Encrypted.Binary
field :email_hash, :string  # SHA-256 hash for lookups
```

## Alternatives Considered

1. **Database-Level Encryption**: Less granular control
2. **Application-Level Encryption (Manual)**: More error-prone
3. **Vault (HashiCorp)**: Overkill for current scale
4. **No Encryption**: Non-compliant with HIPAA

## Security Measures

- Encryption keys stored in environment variables
- SHA-256 hashing for email lookups
- Audit logging for all PII access
- Key rotation procedure documented

## Notes

- Cloak is battle-tested in production Elixir applications
- AES-256-GCM provides authenticated encryption
- Can migrate to Vault later if needed for key management
