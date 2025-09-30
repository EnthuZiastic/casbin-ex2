# CasbinEx2 Project Overview

## Purpose
CasbinEx2 is a powerful authorization library for Elixir, providing a comprehensive implementation of the Casbin authorization framework. It supports multiple access control models including ACL, RBAC, and ABAC.

## Key Features
- Multiple Access Control Models: ACL, RBAC, ABAC support
- Process-Based Architecture: GenServer-based enforcement with OTP supervision
- Database Persistence: Ecto SQL adapter for database-backed policy storage
- High Performance: Cached enforcer for improved performance
- Thread Safety: Synchronized enforcer for concurrent access
- Distributed Enforcement: Multi-node policy synchronization with watchers
- Dynamic Management: Runtime policy and role management
- Flexible Adapters: File and database adapters included
- Batch Operations: Batch enforcement and policy management
- Comprehensive API: Full RBAC API with domain support

## Tech Stack
- Language: Elixir (~> 1.18)
- Framework: OTP with GenServer architecture
- Database: Ecto SQL with PostgreSQL support
- Dependencies:
  - ecto_sql (~> 3.10)
  - postgrex (~> 0.17)
  - jason (~> 1.4)
  - credo (~> 1.7) - for code quality
  - ex_doc (~> 0.30) - for documentation
  - dialyxir (~> 1.3) - for static analysis

## Core Architecture
- Adapter Pattern: Pluggable storage backends (File, Ecto, Batch)
- Model-based Configuration: Policy models define authorization rules
- Enforcer Services: GenServer-based enforcement with supervision
- Transaction Support: Atomic operations for policy changes
- Memory Management: Session persistence and project context