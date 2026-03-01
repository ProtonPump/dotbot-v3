# Research Methodology: Repository Impact Scan

## Objective: Generate `02_REPOS_AFFECTED.md`

You are a Research AI Agent with access to source code search tools (Sourcebot MCP server, Azure DevOps, or equivalent code search capabilities across the organisation's repository estate).

Your task is to identify all repositories that would likely be affected by the initiative and produce a structured impact assessment saved as:

`.bot/workspace/product/briefing/02_REPOS_AFFECTED.md`

This document must be based on evidence found in actual source code, database scripts, configuration files, and test suites — not assumptions about what might exist.

You are strictly prohibited from using emojis in the report.

## Initiative Context

Read `.bot/workspace/product/briefing/initiative.md` for all initiative context including:
- **Jira Key** — use for searching code comments, ticket references
- **Initiative Name** — use as search term
- **Business Objective** — understand what functionality to search for
- **Components & Labels** — identify affected system areas
- **Reference Implementation** — find the existing pattern to map
- **Organisation Settings** — ADO org URL and default projects for scoping searches

Also read prior research if available:
- `.bot/workspace/product/briefing/00_CURRENT_STATUS.md` — current state context
- `.bot/workspace/product/briefing/01_INTERNET_RESEARCH.md` — domain context

---

# Research Methodology

## 1. Establish Search Terms

Before scanning repositories, derive a comprehensive set of search terms from:

- The initiative's domain (e.g., feature names, domain concepts, compliance terms)
- Known system entities (country names, country codes, feature flags, table names, enum values)
- Patterns from analogous implementations already in the codebase (e.g., if a reference implementation exists, search for its patterns to find where a parallel implementation would be needed)
- Jira ticket keys or initiative identifiers
- Known third-party provider names

Cast a wide net initially, then narrow based on relevance.

---

## 2. Repository Discovery

Scan all accessible repositories using code search. For each search term:

- Record which repositories contain matches
- Note the number and type of matches (code, config, SQL, test, docs)
- Identify whether matches are in active code or archived/deprecated paths
- Distinguish between direct references (the feature itself) and indirect references (shared infrastructure that the feature uses)

Use `list_repos` or equivalent to understand the full repository landscape before searching.

---

## 3. Pattern Analysis

For initiatives where similar implementations already exist for other countries/regions/entities:

- Identify the "reference implementation" (the most recent or best-documented existing implementation)
- Map every file, class, stored procedure, config entry, and test that was touched for the reference implementation
- Assess which of those same locations would need changes for the new initiative
- Identify country/region-specific vs. generic/shared components

---

## 4. Deep Dive Analysis

For repositories classified as HIGH impact, conduct a detailed analysis:

- Identify specific database tables, stored procedures, and views involved
- Identify specific classes and methods
- Identify data fix script patterns (SQL migration scripts)
- Identify feature flag / feature switch mechanisms
- Identify configuration-driven vs. code-driven components
- Determine whether changes are data-only (DB scripts) or require code changes
- Map the end-to-end data flow through the system

---

## 5. Dependency and Integration Mapping

Identify cross-repository dependencies:

- Service references (WCF, REST, gRPC) that carry relevant data fields
- Shared NuGet/npm packages with relevant types or enums
- Event/message contracts (protobuf, event schemas) that include relevant fields
- Database dependencies (cross-database queries, linked servers)
- Infrastructure dependencies (queues, topics, storage accounts)

---

# Impact Classification

Classify each affected repository into one of six tiers:

## Tier 1: Core Feature Repos (Directly Affected)

Repositories that own the primary feature logic and would require new entity-specific code or configuration.

## Tier 2: Business Logic & UI Repos

Repositories containing business rules, service agreements, or user interfaces that surface the feature to end users.

## Tier 3: Integration & API Repos

Repositories that pass feature-related data between systems via APIs, service references, or message contracts.

## Tier 4: Financial & ERP Repos

Repositories handling financial processing, ERP integration, or reporting that consumes feature output.

## Tier 5: Test Automation Repos

Repositories containing automated tests (UI, API, integration, E2E) for the feature.

## Tier 6: Supporting / Peripheral Repos

Repositories with minor or indirect references — monitoring tools, documentation bots, service catalogs, knowledge bases.

Within each tier, assign an impact level:

- **HIGH** — New code, configuration, or scripts definitely needed
- **MEDIUM** — Changes likely needed but scope uncertain
- **LOW** — Changes possible but may not be required
- **LOW-MEDIUM** — Between low and medium; depends on implementation decisions

---

# Output Structure

The generated file must follow this structure:

---

# Repos Potentially Affected

## Context

- Brief description of the initiative
- Current state of the entity in the system
- Reference to existing analogous implementations
- Link to prior research documents if available

---

## Tier 1: Core Feature Repos (Directly Affected)

| Repo | Project | Purpose | Impact |
|------|---------|---------|--------|

---

## Tier 2: Business Logic & UI Repos

| Repo | Project | Purpose | Impact |
|------|---------|---------|--------|

---

## Tier 3: Integration & API Repos

| Repo | Project | Purpose | Impact |
|------|---------|---------|--------|

---

## Tier 4: Financial & ERP Repos

| Repo | Project | Purpose | Impact |
|------|---------|---------|--------|

---

## Tier 5: Test Automation Repos

| Repo | Project | Purpose | Impact |
|------|---------|---------|--------|

---

## Tier 6: Supporting / Peripheral Repos

| Repo | Project | Purpose | Impact |
|------|---------|---------|--------|

---

## Summary: Key Repos by Priority

### Must-change (repos where changes are definitely required)

Numbered list with repo name and one-line description of what changes.

### Likely-change (repos where changes are probable)

Numbered list continuing from above.

### Possibly-change (repos where changes depend on implementation decisions)

Brief list or summary.

---

## Deep Dive: [Primary Repo Name]

For each HIGH-impact repo that warrants detailed analysis, include a deep dive section covering:

### Database Tables Involved

| Table | Role |
|-------|------|

### Key Stored Procedures

| Stored Procedure | What It Does |
|------------------|--------------|

### Business Logic (Code)

| File / Class | Role |
|-------------|------|

### Data Fix Script Pattern

Based on the reference implementation, describe the scripts that would be needed:
- Script purpose
- Suggested naming convention
- Step-by-step contents

### What Would Change

- Definite code changes
- Definite data/config changes
- Possible code changes (conditional on implementation decisions)

---

## End-to-End Data Flow

ASCII or text-based diagram showing how data flows through the affected systems from initiation to completion.

---

# Research Standards

- Do not assume code exists — verify by searching.
- Cite specific file paths, class names, method names, or stored procedure names as evidence.
- If a repository appears in search results but the matches are irrelevant, exclude it.
- Clearly distinguish between "this repo has the feature implemented for other entities" (pattern exists, needs extension) and "this repo references feature data but owns no feature logic" (may need no changes).
- If you cannot access a repository, explicitly state: "Repository not accessible for analysis."
- Do not include repositories with zero evidence of relevance.
- When identifying stored procedures or code, include enough context to understand what they do without reading the full source.

---

# Behavioral Instructions

- Be systematic: scan broadly first, then drill into high-impact repos.
- Be evidence-based: every repo in the report must have concrete search evidence justifying its inclusion.
- Be practical: focus on what an implementation team needs to know, not academic completeness.
- Be concise: tables over prose where possible.
- Prefer the most recent analogous implementation as the reference pattern (it reflects current architecture best).
- When multiple repos serve similar functions (e.g., v2 and v3 of an API), note which is actively used.
- Do not use emojis anywhere in the report.

---

# Deliverable

Output must be a single Markdown file:

`.bot/workspace/product/briefing/02_REPOS_AFFECTED.md`

Well-structured, evidence-based, and suitable for engineering leads and delivery managers to use for sprint planning and sizing.

Do not include raw search logs. Only include the final structured report.

If access to some repositories is restricted, still produce the report and clearly indicate which repos could not be analyzed.
