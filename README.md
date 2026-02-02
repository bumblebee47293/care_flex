# 🏥 CareFlex

> **A Healthcare Scheduling & Benefits Engagement Platform**

CareFlex is a production-grade Elixir/Phoenix application demonstrating enterprise-level healthcare system design with real-time capabilities, intelligent automation, and HIPAA-aware security practices.

[![Elixir](https://img.shields.io/badge/Elixir-1.15+-purple.svg)](https://elixir-lang.org)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.7+-orange.svg)](https://phoenixframework.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-blue.svg)](https://postgresql.org)

---

## 🎯 Problem Statement

Healthcare organizations face critical operational challenges:

- **Patient Engagement**: Patients with varied abilities struggle to manage care schedules
- **Call Center Efficiency**: Staff lack real-time visibility into patient status and appointments
- **No-Show Rates**: High cancellation and no-show rates impact care delivery
- **System Integration**: Disconnected external systems (benefits, providers) create data silos
- **Accessibility**: Communication barriers for patients with disabilities

CareFlex addresses these challenges with a modern, scalable platform built on Elixir/Phoenix.

---

## ✨ Key Features

### 1. **Patient Care Scheduling**

- Timezone-aware appointment management
- Accessible UI for patients with varied abilities
- SMS/Voice reminders based on patient preferences
- Self-service rescheduling and cancellation

### 2. **Real-Time Call Center Dashboard**

- Live appointment updates via GraphQL subscriptions
- Patient status visibility
- Presence tracking for agents
- Real-time statistics and alerts

### 3. **Intelligent Automation**

- No-show risk prediction using statistical models
- Automated appointment reminders (24h and 2h before)
- Auto-reschedule suggestions
- Background job processing with Oban

### 4. **External System Integration**

- Insurance benefits API integration (mocked)
- Care provider availability sync
- Circuit breaker pattern for resilience
- Retry logic with exponential backoff

### 5. **Secure Communication**

- Multi-channel notifications (SMS, Voice, Email)
- Patient communication preferences
- Auditable message logs
- Template-based messaging

### 6. **Enterprise Security**

- Field-level PII encryption (AES-256-GCM)
- Role-based access control (Patient/Agent/Admin)
- Comprehensive audit logging
- Soft deletes with retention policies
- HIPAA-aware data handling

---

## 🚀 Getting Started

### Prerequisites

- **Elixir** 1.15+ and **Erlang** 26+
- **PostgreSQL** 15+
- **Node.js** 18+ (for assets)

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/yourusername/care_flex.git
   cd care_flex
   ```

2. **Install dependencies**

   ```bash
   mix deps.get
   ```

3. **Set up the database**

   ```bash
   mix ecto.setup
   ```

4. **Start the Phoenix server**

   ```bash
   mix phx.server
   ```

5. **Visit the GraphiQL playground**
   ```
   http://localhost:4000/graphiql
   ```

---

## 🧪 Testing

```bash
# Run all tests
mix test

# Run with coverage
mix coveralls.html

# Run code quality checks
mix credo --strict
mix dialyzer
```

---

## 🔐 Security

### PII Encryption

All sensitive patient data is encrypted at rest using AES-256-GCM.

### Audit Logging

Every sensitive operation is logged with user, action, and changes tracked.

### Role-Based Access Control

- **Patient**: Can only access own data
- **Agent**: Can view/update patient appointments
- **Admin**: Full system access
- **System**: Background job operations

---

## 📚 Documentation

- [Architecture Decision Records](docs/decisions/)
- [Security Guide](docs/SECURITY.md)

---

_Built with ❤️ using Elixir and Phoenix_
