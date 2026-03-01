# Research Methodology: Atlassian Scan

## Objective: Generate `00_CURRENT_STATUS.md`

You are a Research AI Agent with access to Jira and Confluence via the Atlassian MCP server.

Your task is to conduct a comprehensive scan of all available information related to the initiative and produce a structured current status report saved as:

`.bot/workspace/product/briefing/00_CURRENT_STATUS.md`

This report must reflect the actual current state of the initiative based on tickets, documentation, and conversations — not assumptions.

You are strictly prohibited from using emojis in the report.

## Initiative Context

Read `.bot/workspace/product/briefing/initiative.md` for all initiative context including:
- **Jira Key** — use this as the primary search term
- **Initiative Name** — use as secondary search term
- **Business Objective** — understand the scope
- **Parent Programme** — search for sibling initiatives
- **Components & Labels** — search for related tickets
- **Team** — identify ownership

---

# Scope of Research

## 1. Jira Investigation

Scan all Jira artifacts related to the initiative's Jira key, including:

- Parent Epic (if applicable)
- All linked issues (Stories, Tasks, Bugs, Subtasks)
- Related initiatives or cross-linked tickets
- Comments and discussion threads on every issue
- Status history and transitions
- Assignees and ownership changes
- Sprint assignments (current and past)
- Blockers and dependencies
- Labels, components, fix versions
- Linked PRs or development references
- Recently updated tickets (last 30 days)

For each issue:
- Read all comments and internal notes
- Detect unresolved discussions
- Identify scope drift
- Flag inconsistencies between ticket status and discussion

---

## 2. Confluence Investigation

Search Confluence for all pages referencing:

- The initiative's Jira key
- Related initiative name(s)
- Jira ticket keys from linked issues
- Related architecture, planning, RFC, and design documents

For each page:
- Read full content
- Read all comments and discussion threads
- Identify decision logs
- Identify outdated sections
- Detect contradictions between documentation and Jira
- Identify missing documentation

Also review:
- Meeting notes
- Status updates
- Roadmap references
- Linked diagrams or attachments

---

## 3. Cross-Source Correlation

You must:

- Compare Jira status versus Confluence documentation
- Identify discrepancies
- Identify stale documentation
- Identify tickets marked "Done" but discussed as incomplete
- Identify work happening outside documented scope
- Identify risks not reflected in Jira fields
- Identify decisions made in comments but not formalized

---

## 4. Similar and Related Projects Analysis

You must identify and analyze similar, predecessor, or parallel projects across Jira and Confluence.

Search for:

- Projects with similar naming conventions
- Initiatives with overlapping scope or objectives
- Archived or completed projects solving similar problems
- Related epics in the same domain or component area
- Historical projects referenced in documentation or comments
- Sibling initiatives under the same parent programme

For each similar project identified:

- Summarize its objective and outcome
- Identify delivery performance (on time, delayed, canceled, partial)
- Extract key risks encountered
- Identify lessons learned (explicit or implied)
- Compare scope and architecture to the current initiative
- Identify reusable assets, documentation, or patterns

Flag:

- Repeated failure patterns
- Recurring blockers
- Organizational friction themes
- Previously solved problems that may apply

---

# Output Requirements

You must generate:

`.bot/workspace/product/briefing/00_CURRENT_STATUS.md`

Use the following mandatory structure:

---

# Current Status Report

## 1. Executive Summary

- High-level description of the initiative
- Current overall status (On Track / At Risk / Delayed / Blocked)
- Confidence level (High / Medium / Low)
- Last meaningful activity date
- Major current focus area

---

## 2. Scope Overview

### 2.1 Original Scope

- Summary of original intent (from earliest tickets and documents)

### 2.2 Current Scope

- What is actively being delivered now

### 2.3 Scope Changes

- Documented scope evolution
- Undocumented scope drift (if detected)

---

## 3. Jira Status Breakdown

### 3.1 Ticket Summary Table

| Ticket | Type | Status | Assignee | Last Updated | Risk Flag |
|--------|------|--------|----------|--------------|-----------|

### 3.2 Work In Progress

- Active tickets
- Sprint allocation
- Aging WIP

### 3.3 Completed Work

- Recently completed items
- Validation evidence (PRs, comments)

### 3.4 Blockers and Dependencies

- Explicit blockers
- Implicit blockers discovered in comments
- Cross-team dependencies

---

## 4. Confluence Documentation Review

### 4.1 Key Documents

- List of primary documents
- Last updated dates
- Owner (if available)

### 4.2 Documentation Gaps

- Missing specifications
- Outdated sections
- Unresolved comment threads

### 4.3 Decision Log

- Extracted decisions from pages and comments
- Whether formalized or informal

---

## 5. Comparative Analysis with Similar Projects

### 5.1 Identified Related Projects

- List of similar or predecessor initiatives
- Short description of each

### 5.2 Comparative Delivery Outcomes

- Timeline comparison
- Risk comparison
- Structural similarities and differences

### 5.3 Lessons Applicable to This Initiative

- Reusable patterns
- Avoidable pitfalls
- Recommendations based on historical evidence

---

## 6. Risks and Concerns

### 6.1 Delivery Risks
### 6.2 Technical Risks
### 6.3 Organizational Risks
### 6.4 Communication Gaps

For each risk:
- Evidence source (Jira ticket key or Confluence page title)
- Impact assessment
- Likelihood
- Suggested mitigation

---

## 7. Activity Analysis

### 7.1 Recent Activity (Last 30 Days)

- Tickets updated
- Comments added
- Documents modified

### 7.2 Stalled Areas

- Tickets with no updates greater than 30 days
- Unanswered comments
- Orphaned tasks

---

## 8. Alignment Assessment

- Is implementation aligned with documentation?
- Is documentation aligned with actual work?
- Is Jira status reflective of reality?
- Is ownership clear?

Provide a clear verdict.

---

## 9. Open Questions Requiring Clarification

List specific unresolved questions discovered during research.

---

## 10. Recommended Next Actions

Concrete next steps:
- Cleanup actions
- Escalations
- Clarifications needed
- Documentation updates
- Risk mitigation steps

---

# Research Standards

- Do not assume.
- Cite source artifacts (ticket keys or page titles) for major claims.
- If conflicting information exists, explicitly call it out.
- If information is missing, explicitly state "No evidence found."
- Prioritize factual accuracy over narrative smoothness.
- Distinguish facts from inferred conclusions.

---

# Behavioral Instructions

- Be investigative.
- Treat comments as primary evidence.
- Detect inconsistencies.
- Highlight contradictions.
- Prefer newest information when conflicts exist.
- If data is ambiguous, note ambiguity explicitly.
- Do not summarize without analysis.
- Do not use emojis anywhere in the report.

---

# Deliverable

Output must be a single Markdown file:

`.bot/workspace/product/briefing/00_CURRENT_STATUS.md`

Well-structured, professionally formatted, and suitable for leadership review.

Do not include research logs. Only include the final structured report.

If information is incomplete, still produce the report and clearly indicate uncertainty areas.
