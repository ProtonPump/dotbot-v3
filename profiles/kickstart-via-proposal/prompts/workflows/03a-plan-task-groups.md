---
name: Plan Task Groups from Proposal
description: Phase 1 — identify implementation-ordered task groups from product documents, architecture, and proposal backlog
version: 1.0
---

# Task Group Planning (Proposal-Driven)

You are a roadmap planning assistant. Your job is to read the product documents, architecture, accepted decisions, and proposal backlog, then identify natural implementation groups ordered by build dependency.

## Goal

Produce a `task-groups.json` manifest with implementation-ordered groups. Each group represents a coherent slice of work that can be built in sequence. **Focus on build dependencies, not product domain boundaries.**

## Important Distinctions

The proposal backlog organizes work by **product domain** (e.g., Subscriptions, CMS, Analytics). You must organize work by **build dependency** — what must be built before what.

For example:
- Entity definitions from Subscriptions, CMS, and Analytics EPICs all go into a "Core Entities & Data Layer" group
- Infrastructure setup from multiple EPICs goes into a "Foundation & Infrastructure" group
- A "User-Facing Interface" group pulls UI work from across all domain EPICs

**Do NOT copy the proposal's EPIC structure into task groups.** EPICs are product-domain groupings. Task groups are implementation-dependency groupings.

## Instructions

### Step 1: Read All Context

Read every file in `.bot/workspace/product/`:
- `mission.md` — Core principles, goals, target audience
- `tech-stack.md` — Technology choices and libraries
- `entity-model.md` — Data model and entity relationships
- `proposal-source.json` — Path to proposal repository

From the proposal repository (path in `proposal-source.json`):
- Read the **latest architecture document** (`architecture/arch-*-v*.md` — highest version)
- Read **all EPIC summary files** (`backlog/epics/E-*.md`) — read each file for scope, dependencies, and feature lists
- **Do NOT read individual feature or story files** — you only need EPIC-level scope for grouping

Read accepted decisions for constraint awareness:
```javascript
mcp__dotbot__decision_list({ status: "accepted" })
```
Note each decision's ID, title, and consequences.

### Step 2: Identify Implementation Groups

Based on all the context above, identify natural implementation groups. Think in terms of **build dependency chains** — each group should bring the product closer to a working state.

Examples of good implementation groups:
1. **Foundation & Infrastructure** — Cloud setup, K8s, managed services, CI/CD
2. **Core Entities & Data Layer** — Entity schemas, migrations, repositories across all domains
3. **Authentication & Identity** — Auth provider, permissions, session management
4. **API Gateway & Service Shell** — API gateway, service scaffolding, health checks
5. **Content Management & Editorial** — CMS integration, editorial workflows
6. **Subscription & Billing** — Payment integration, entitlement enforcement
7. **Content Delivery & UX** — Frontend rendering, content pages, search
8. **External Integrations** — Third-party API integrations (social, video, AI)
9. **Background Processing** — Scheduled jobs, event handlers, queues, notifications
10. **Admin & Operations** — Admin portal, monitoring dashboards
11. **Mobile Application** — React Native app, mobile-specific features

Adapt to the actual project. Merge small groups, split large ones. There is **no artificial limit** on the number of groups — use as many as the project naturally requires. For a large project, 10-20 groups is typical.

**Do NOT create groups for:**
- Generic "Polish & Testing" — testing is part of every group
- Vague "Enhancements" — each group delivers concrete functionality
- Human activities (workshops, vendor evaluations, onboarding)
- Project management activities

### Step 3: Define Group Dependencies

Groups must have explicit dependencies via `depends_on`:
- Infrastructure groups have no dependencies
- Entity/data groups depend on infrastructure
- Service groups depend on the entities they use
- Feature groups depend on the services they call
- UI groups depend on the APIs they consume
- Integration groups depend on the services they extend

Use the architecture document's container diagram to identify service boundaries and their dependencies.

### Step 3b: Estimate Effort Days

Assign `effort_days` to each group — estimated developer-days for a skilled human.

| Complexity | Effort Days | Examples |
|------------|-------------|----------|
| Simple | 2-5 | Config setup, simple CRUD entities |
| Standard | 5-15 | Auth integration, standard feature set |
| Complex | 15-30 | Multi-entity business logic, complex integrations |
| Major | 30-60 | Large subsystems, multiple integration points |
| Very Large | 60-100 | Platform-wide capabilities spanning many services |

### Step 4: Assign Priority Ranges

Each group gets a non-overlapping priority range that encodes execution order. For a large project with many groups, use wider ranges:

| Order | Priority Range | Typical Groups |
|-------|---------------|----------------|
| 1 | 1-50 | Foundation, infrastructure |
| 2 | 51-100 | Core entities, data layer |
| 3 | 101-200 | Auth, API gateway |
| 4 | 201-400 | Core business services |
| 5 | 401-600 | Content delivery, integrations |
| 6 | 601-800 | Background processing, notifications |
| 7 | 801-1000 | UI, mobile, admin |

Adjust ranges based on actual group count. Ensure ranges don't overlap.

### Step 5: Write task-groups.json

Write the file directly to `.bot/workspace/product/task-groups.json`.

**Do NOT use MCP tools to create tasks.** Just write the JSON file.

```json
{
  "generated_at": "2026-01-01T00:00:00Z",
  "project_name": "Project Name from mission.md",
  "total_groups": 15,
  "groups": [
    {
      "id": "grp-1",
      "name": "Foundation & Infrastructure",
      "order": 1,
      "description": "Cloud infrastructure, Kubernetes cluster, managed data services, CI/CD pipeline, API gateway base configuration",
      "effort_days": 25,
      "scope": [
        "Cloud account and VPC provisioning",
        "Kubernetes cluster with multi-AZ",
        "Managed PostgreSQL, Redis, OpenSearch, message queue",
        "CDN and edge network",
        "Observability stack (Prometheus, Grafana)",
        "CI/CD pipeline with SAST"
      ],
      "acceptance_criteria": [
        "All managed services operational in dev and staging",
        "CI/CD pipeline runs on every push",
        "Monitoring dashboards show service health"
      ],
      "estimated_task_count": 15,
      "depends_on": [],
      "priority_range": [1, 50],
      "category_hint": "infrastructure",
      "applicable_decisions": ["dec-XXXXXXXX"]
    }
  ]
}
```

### Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique group ID: `grp-1`, `grp-2`, etc. |
| `name` | Yes | Human-readable group name |
| `order` | Yes | Execution order (1 = first) |
| `description` | Yes | 2-3 sentence summary — clear enough for task creation to understand what belongs here |
| `effort_days` | Yes | Estimated developer-days (1-100) |
| `scope` | Yes | Array of specific items to implement |
| `acceptance_criteria` | Yes | Group-level success conditions |
| `estimated_task_count` | Yes | Expected number of tasks |
| `depends_on` | Yes | Array of group IDs this depends on (empty for root groups) |
| `priority_range` | Yes | `[min, max]` — priority range for tasks in this group |
| `category_hint` | Yes | Default category: infrastructure, core, feature, enhancement, integration |
| `applicable_decisions` | No | Decision IDs that constrain this group's implementation |

### Guidelines

- **Group descriptions must be clear and unambiguous** — task creation prompts will use these descriptions to decide which group a task belongs to
- **Scope items** should map to roughly 1-3 tasks each when expanded later
- **Each scope item** should reference which proposal EPICs/features it covers (e.g., "Content delivery API endpoints (from E-05)")
- **Priority ranges** must not overlap between groups
- **applicable_decisions** should list decision IDs whose consequences directly affect the group's implementation

## Output

Write `.bot/workspace/product/task-groups.json` and confirm with a brief summary:
- Number of groups created
- Total estimated tasks
- Total estimated effort (days)
- Group names and their order
- Which proposal EPICs are covered by which groups
