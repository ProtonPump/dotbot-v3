---
name: Synthesize Product Documents from Proposal
description: Phase 0b — read proposal artifacts and synthesize mission.md, tech-stack.md, entity-model.md
version: 1.0
---

# Synthesize Product Documents from Proposal

You are a product documentation assistant. Your job is to read a project proposal, architecture document, and project context, then synthesize them into dotbot's standard product document format.

## Goal

Create three product documents that capture the essential information from the proposal in a format that dotbot's core workflow can consume during task analysis and execution.

## Instructions

### Step 1: Locate Proposal Source

Read the proposal source configuration:
```
.bot/workspace/product/proposal-source.json
```

This contains the `proposal_path` — the absolute path to the project proposal repository.

### Step 2: Read Proposal Artifacts

Read the following files from the proposal repository (use the paths from `proposal_path`):

1. **Latest proposal** — find the highest-versioned `proposal-*-v*.md` file in `{proposal_path}/proposals/` (exclude files ending in `-client.md`)
2. **Latest architecture** — find the highest-versioned `arch-*-v*.md` file in `{proposal_path}/architecture/`
3. **Project context** — read `{proposal_path}/context/project-context.md`

Also read the accepted decisions already imported into dotbot:
```javascript
mcp__dotbot__decision_list({ status: "accepted" })
```

### Step 3: Write mission.md

Write `.bot/workspace/product/mission.md` containing:

## Executive Summary

A concise 2-3 paragraph summary of:
- What is being built (product name, type, target market)
- Who it's for (target users, personas)
- Why it matters (business case, value proposition)
- Key constraints (timeline, budget, mandatory integrations)

## Core Principles

Extract 5-8 core principles from the proposal and accepted decisions. These should be non-negotiable guardrails for implementation:
- e.g., "GDPR compliance by design", "German-language only", "Multi-AZ infrastructure"

## Goals

Extract concrete success metrics and delivery targets from the proposal:
- Subscriber targets, conversion rates, uptime requirements
- Binding deadlines
- Key milestones

## Target Audience

Describe each user type/persona identified in the proposal:
- Subscribers (by tier), editorial staff, administrators, advertisers, B2B clients

## Scope Boundaries

- **In scope:** Major platform capabilities
- **Out of scope:** Explicitly excluded items from the proposal

### Step 4: Write tech-stack.md

Write `.bot/workspace/product/tech-stack.md` containing:

## Runtime & Framework

Extract confirmed technology choices from the architecture document and accepted decisions:
- Frontend framework, backend framework, mobile framework
- Reference the relevant decision IDs

## Database & Storage

- Primary database, caching, search, message queue, object storage
- Reference architecture container diagram for details

## External Integrations

List each external system the platform integrates with:
- Name, purpose, integration pattern (API, webhook, SDK)
- Reference relevant ADR decisions

## Infrastructure

- Cloud provider, container orchestration, CDN
- Deployment topology (multi-AZ, environments)
- Monitoring and observability stack

## Development Tools

- CI/CD, testing frameworks, code quality tools
- Any AI-assisted development tooling

### Step 5: Write entity-model.md

Write `.bot/workspace/product/entity-model.md` containing:

## Core Entities

Extract the data model from the architecture document. For each major entity:
- **Entity name** — description
- Key fields and their types
- Relationships to other entities

## Entity Relationship Diagram

Include a Mermaid ER diagram showing:
- All major entities
- Relationships (one-to-many, many-to-many)
- Key fields

```mermaid
erDiagram
    USER ||--o{ SUBSCRIPTION : has
    ...
```

## Key Constraints

- Multi-tenant readiness (tenant_id on all entities)
- GDPR data subject fields
- Audit trail requirements

## Output

Write all three files to `.bot/workspace/product/` and confirm with a brief summary of what was synthesized.
