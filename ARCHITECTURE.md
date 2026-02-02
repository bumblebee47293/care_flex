# CareFlex - System Architecture

## Overview

CareFlex is a production-grade healthcare scheduling and benefits engagement platform built with Elixir/Phoenix. The system follows a clean architecture pattern with clear separation of concerns using Phoenix contexts and an umbrella application structure.

## Architecture Principles

### 1. **Umbrella Application Structure**

The project is organized as an Elixir umbrella app with two main applications:

- **`careflex_core`**: Business logic, database, background workers
- **`careflex_web`**: GraphQL API, WebSocket channels, HTTP endpoints

This separation enables:

- Independent deployment of API and background workers
- Clear boundaries between business logic and presentation
- Easier testing and maintenance

### 2. **Domain-Driven Design with Phoenix Contexts**

The core application is organized into bounded contexts:

```
careflex_core/
├── Care/          # Patient management
├── Scheduling/    # Appointment scheduling
├── Benefits/      # Benefits tracking and eligibility
├── Audit/         # Security and compliance logging
└── Notifications/ # Multi-channel communications
```

Each context encapsulates:

- Domain models (Ecto schemas)
- Business logic functions
- Database queries
- Context-specific validations

### 3. **Layered Architecture**

```
┌─────────────────────────────────────────┐
│         GraphQL API Layer               │
│  (Absinthe Schema, Resolvers, Types)    │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│      Business Logic Layer               │
│    (Phoenix Contexts, Domain Logic)     │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│       Data Access Layer                 │
│     (Ecto Schemas, Repo, Queries)       │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│         PostgreSQL Database             │
│   (Encrypted PII, Audit Logs, Indexes)  │
└─────────────────────────────────────────┘
```

## Core Components

### Database Layer

**Technology**: PostgreSQL 15+

**Key Features**:

- Field-level PII encryption using Cloak (AES-256-GCM)
- Soft deletes for data retention compliance
- Comprehensive indexing for performance
- JSONB for flexible metadata storage
- Decimal precision for financial data

**Tables**:

1. `patients` - Patient demographics with encrypted PII
2. `appointments` - Scheduling with timezone support
3. `benefits` - Benefits allocation and usage tracking
4. `audit_logs` - Immutable security audit trail
5. `notifications` - Communication delivery tracking

### Business Logic (Phoenix Contexts)

#### Care Context

**Responsibility**: Patient management and demographics

**Key Functions**:

- Patient CRUD with encrypted PII
- Email-based lookup using SHA-256 hashes
- Soft delete support
- Search by name (encrypted field search)

**Security**:

- All PII fields encrypted at rest
- Audit logging on all mutations
- Email hashing for secure lookups

#### Scheduling Context

**Responsibility**: Appointment scheduling and management

**Key Functions**:

- Appointment creation with conflict detection
- Timezone-aware scheduling
- Reschedule and cancellation
- No-show risk prediction (statistical model)
- Real-time updates via PubSub

**Business Rules**:

- No overlapping appointments for same patient
- Timezone conversion for display
- Risk score calculation based on history
- Automatic reminder scheduling

#### Benefits Context

**Responsibility**: Benefits eligibility and usage tracking

**Key Functions**:

- Eligibility checking with balance validation
- Usage recording with decimal precision
- Benefit expiration management
- External API synchronization

**Business Rules**:

- Cannot exceed allocated amounts
- Automatic status updates (active → depleted/expired)
- Period-based benefit allocation

#### Audit Context

**Responsibility**: Security and compliance logging

**Key Functions**:

- Immutable audit log creation
- User action tracking
- Change history recording
- IP and user agent logging

**Compliance**:

- HIPAA-aware logging
- Immutable records (no updates/deletes)
- Comprehensive change tracking

#### Notifications Context

**Responsibility**: Multi-channel patient communications

**Key Functions**:

- SMS notifications
- Voice call notifications
- Template-based messaging
- Delivery tracking
- Patient preference handling

### GraphQL API Layer

**Technology**: Absinthe 1.7+

**Architecture**:

```
Schema (schema.ex)
  ├── Types (schema/*_types.ex)
  ├── Queries
  ├── Mutations
  └── Subscriptions

Resolvers (resolvers/*.ex)
  └── Business logic delegation to contexts

Middleware
  ├── Authentication (future)
  ├── Authorization (future)
  └── Error handling
```

**Features**:

- Cursor-based pagination
- Real-time subscriptions over WebSocket
- Dataloader for N+1 prevention
- Comprehensive error handling
- Audit context injection

**Subscriptions**:

1. `appointmentScheduled` - Real-time appointment creation
2. `appointmentUpdated` - Real-time appointment changes

### Background Workers (Oban)

**Technology**: Oban 2.17+

**Workers**:

1. **ReminderWorker**
   - Schedule: Event-driven (24h and 2h before appointment)
   - Function: Send appointment reminders
   - Channels: SMS or Voice based on preferences

2. **NoShowPredictor**
   - Schedule: Daily cron (2:00 AM)
   - Function: Calculate no-show risk scores
   - Algorithm: Statistical analysis of patient history

3. **BenefitsSyncWorker**
   - Schedule: Daily cron (3:00 AM)
   - Function: Sync benefits from external API
   - Features: Batch processing, error handling

**Configuration**:

- Retry logic with exponential backoff
- Dead letter queue for failed jobs
- Job monitoring and metrics

### External Integrations

**Pattern**: Mock implementations with realistic behavior

**Integrations**:

1. **BenefitsAPI** - Insurance benefits provider
2. **ProviderAPI** - Care provider availability
3. **SMSProvider** - SMS delivery (Twilio-style)
4. **VoiceProvider** - Voice calls (Twilio-style)

**Features**:

- Simulated network delays
- Realistic failure scenarios
- Circuit breaker pattern (future)
- Retry logic with backoff

### Real-Time Features

**Technology**: Phoenix PubSub + Absinthe Subscriptions

**Implementation**:

```elixir
# Broadcasting
Phoenix.PubSub.broadcast(
  CareflexCore.PubSub,
  "appointments",
  {:appointment_scheduled, appointment}
)

# Subscription
subscription do
  field :appointment_scheduled, :appointment do
    config fn _args, _context ->
      {:ok, topic: "appointments"}
    end
  end
end
```

**Use Cases**:

- Call center dashboard updates
- Real-time appointment notifications
- Live status changes

## Security Architecture

### Encryption

**Technology**: Cloak with AES-256-GCM

**Encrypted Fields**:

- Patient: `first_name`, `last_name`, `email`, `phone`, `date_of_birth`
- All PII fields encrypted at rest

**Key Management**:

- Encryption keys stored in environment variables
- Vault module for key management
- Automatic encryption/decryption via Ecto

### Audit Logging

**Strategy**: Comprehensive, immutable audit trail

**Logged Events**:

- All patient data mutations
- Appointment scheduling/changes
- Benefits usage
- Administrative actions

**Audit Record**:

```elixir
%AuditLog{
  user_id: integer,
  user_role: :admin | :agent | :patient,
  action: string,
  resource_type: string,
  resource_id: integer,
  changes: map,
  metadata: map,
  ip_address: string,
  user_agent: string
}
```

### Data Protection

1. **Soft Deletes**: All records retain `deleted_at` timestamp
2. **Email Hashing**: SHA-256 hashes for secure lookups
3. **Input Validation**: Comprehensive changeset validations
4. **SQL Injection Protection**: Ecto parameterized queries

## Testing Strategy

### Test Organization

```
test/
├── careflex_core/
│   ├── care_test.exs           # Context tests
│   ├── scheduling_test.exs
│   ├── benefits_test.exs
│   └── workers/
│       ├── reminder_worker_test.exs
│       ├── no_show_predictor_test.exs
│       └── benefits_sync_worker_test.exs
└── support/
    ├── factory.ex              # ExMachina factories
    └── data_case.ex            # Test helpers
```

### Test Coverage

- **Unit Tests**: All context functions
- **Integration Tests**: Worker execution
- **Edge Cases**: Encryption, soft deletes, conflicts
- **Async Tests**: For performance

### Test Tools

- **ExUnit**: Test framework
- **ExMachina**: Test data factories
- **Oban.Testing**: Worker testing
- **Ecto.Sandbox**: Database isolation

## CI/CD Pipeline

### GitHub Actions Workflow

**Jobs**:

1. **Test** - Multi-version testing (Elixir 1.15/1.16, OTP 26.0/26.1)
2. **Code Quality** - Format, Credo, Dialyzer
3. **Security** - Dependency audit, Sobelow

**Features**:

- PostgreSQL service container
- Dependency caching
- Parallel job execution
- Warnings as errors

### Code Quality Tools

1. **Credo**: Static code analysis
2. **Dialyzer**: Type checking
3. **Sobelow**: Security scanning
4. **mix format**: Code formatting

## Deployment Architecture

### Recommended: Fly.io

```
┌─────────────────────────────────────────┐
│         Load Balancer (Fly Proxy)       │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│    Phoenix App (Multiple Instances)     │
│  - GraphQL API                          │
│  - WebSocket Subscriptions              │
│  - Background Workers (Oban)            │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│      PostgreSQL (Fly Postgres)          │
│  - Encrypted PII                        │
│  - Audit Logs                           │
└─────────────────────────────────────────┘
```

### Environment Configuration

**Required Secrets**:

- `DATABASE_URL` - PostgreSQL connection
- `SECRET_KEY_BASE` - Phoenix secret
- `CLOAK_KEY` - Encryption key
- `PHX_HOST` - Application host

### Scaling Considerations

1. **Horizontal Scaling**: Multiple Phoenix instances
2. **Database**: Read replicas for queries
3. **Oban**: Distributed job processing
4. **PubSub**: Redis adapter for multi-node

## Performance Optimizations

### Database

- Indexes on foreign keys and lookup fields
- Email hash index for fast lookups
- Composite indexes for common queries
- JSONB indexes for metadata queries

### GraphQL

- Dataloader for N+1 prevention
- Cursor-based pagination
- Query complexity limits (future)
- Field-level caching (future)

### Background Jobs

- Batch processing for bulk operations
- Job prioritization
- Rate limiting for external APIs

## Monitoring & Observability

### Logging

- Structured logging with Logger
- Request ID tracking
- Error tracking with context
- Audit log retention

### Metrics (Future)

- AppSignal or New Relic integration
- Custom business metrics
- Performance monitoring
- Error rate tracking

## Technology Stack Summary

| Layer           | Technology        | Version |
| --------------- | ----------------- | ------- |
| Language        | Elixir            | 1.15+   |
| Runtime         | OTP               | 26.0+   |
| Web Framework   | Phoenix           | 1.7+    |
| Database        | PostgreSQL        | 15+     |
| ORM             | Ecto              | 3.11+   |
| GraphQL         | Absinthe          | 1.7+    |
| Background Jobs | Oban              | 2.17+   |
| Encryption      | Cloak             | 1.1+    |
| Testing         | ExUnit, ExMachina | -       |
| Code Quality    | Credo, Dialyzer   | -       |
| Security        | Sobelow           | -       |

## Future Enhancements

1. **Authentication**: Guardian JWT implementation
2. **Authorization**: Role-based access control
3. **Caching**: Redis for session and query caching
4. **Rate Limiting**: API request throttling
5. **Monitoring**: AppSignal or New Relic
6. **Frontend**: React/Vue with Apollo Client
7. **Mobile**: React Native app
8. **ML Models**: Advanced no-show prediction

---

_This architecture supports a production-ready, HIPAA-aware healthcare platform with real-time capabilities, comprehensive security, and enterprise-grade reliability._
