# ADR 001: Use Elixir Umbrella Application Structure

## Status

Accepted

## Context

We need to build a healthcare scheduling platform with clear separation between business logic and API layers. The system requires:

- Background job processing (Oban workers)
- GraphQL API with real-time subscriptions
- Potential for independent deployment of components
- Clear architectural boundaries

## Decision

We will use an Elixir umbrella application structure with two main apps:

- `careflex_core`: Business logic, database, background workers
- `careflex_web`: GraphQL API, WebSocket channels, HTTP endpoints

## Consequences

### Positive

- **Clear Separation**: Business logic is completely isolated from presentation layer
- **Independent Deployment**: Can deploy API and workers separately if needed
- **Easier Testing**: Can test business logic without starting the web server
- **Scalability**: Can scale API and workers independently
- **Maintainability**: Clear boundaries make code easier to navigate

### Negative

- **Initial Complexity**: Slightly more complex setup than single application
- **Dependency Management**: Need to manage dependencies across apps
- **Learning Curve**: Team needs to understand umbrella structure

## Alternatives Considered

1. **Single Phoenix Application**: Simpler but less separation
2. **Separate Repositories**: Too much overhead for this project size
3. **Microservices**: Overkill for current requirements

## Notes

- This decision aligns with Elixir best practices for medium-to-large applications
- Umbrella structure is well-supported by Mix and deployment tools
- Can always consolidate later if separation proves unnecessary
