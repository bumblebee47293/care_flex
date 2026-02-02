# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records for the CareFlex project.

## What is an ADR?

An Architecture Decision Record (ADR) captures an important architectural decision made along with its context and consequences.

## Format

Each ADR follows this structure:

- **Title**: Short noun phrase
- **Status**: Proposed, Accepted, Deprecated, Superseded
- **Context**: What is the issue we're seeing that is motivating this decision?
- **Decision**: What is the change we're proposing/doing?
- **Consequences**: What becomes easier or more difficult?
- **Alternatives Considered**: What other options were evaluated?

## Index

| ADR                                          | Title                                     | Status   |
| -------------------------------------------- | ----------------------------------------- | -------- |
| [001](001-umbrella-application-structure.md) | Use Elixir Umbrella Application Structure | Accepted |
| [002](002-graphql-over-rest.md)              | Use GraphQL Instead of REST               | Accepted |
| [003](003-cloak-for-pii-encryption.md)       | Use Cloak for PII Encryption              | Accepted |
| [004](004-oban-for-background-jobs.md)       | Use Oban for Background Job Processing    | Accepted |
| [005](005-soft-deletes-for-retention.md)     | Use Soft Deletes for Data Retention       | Accepted |

## Creating New ADRs

1. Copy the template
2. Number sequentially (e.g., 006)
3. Use kebab-case for filename
4. Update this README index
5. Commit with message: "docs: add ADR NNN - Title"

## References

- [ADR GitHub Organization](https://adr.github.io/)
- [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
