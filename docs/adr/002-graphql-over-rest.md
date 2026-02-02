# ADR 002: Use GraphQL Instead of REST

## Status

Accepted

## Context

We need to design an API for call center dashboards that will:

- Display complex nested data (patients with appointments and benefits)
- Support real-time updates for live dashboards
- Allow flexible querying based on different dashboard views
- Minimize over-fetching and under-fetching of data

## Decision

We will use GraphQL (via Absinthe) as our primary API technology instead of REST.

## Consequences

### Positive

- **Flexible Queries**: Clients can request exactly the data they need
- **Real-Time Support**: Built-in subscription support for live updates
- **Strong Typing**: Schema provides clear API contract
- **Single Endpoint**: Simplifies API management
- **Nested Data**: Easy to fetch related data in single query
- **Developer Experience**: GraphiQL provides excellent API exploration

### Negative

- **Learning Curve**: Team needs to learn GraphQL concepts
- **Caching Complexity**: HTTP caching less straightforward than REST
- **Query Complexity**: Need to implement query cost analysis
- **Tooling**: Some REST tools don't work with GraphQL

## Alternatives Considered

1. **REST API**: Simpler but requires multiple endpoints and over-fetching
2. **gRPC**: Better performance but poor browser support
3. **WebSockets Only**: Too low-level for our needs

## Implementation Details

- Using Absinthe 1.7+ for GraphQL implementation
- Phoenix Channels for subscription transport
- Dataloader for N+1 query prevention
- Cursor-based pagination for large datasets

## Notes

- GraphQL is well-suited for dashboard applications
- Real-time subscriptions are critical for call center use case
- Can add REST endpoints later if needed for specific use cases
