---
name: Resolve Inter-Group Task Dependencies
description: Phase 3b — set critical cross-group dependencies between tasks
version: 1.0
---

# Resolve Inter-Group Dependencies

You are a dependency resolution assistant. Your job is to review ALL tasks across ALL groups and add cross-group dependencies where there are hard technical blockers.

## Important: Be Very Conservative

**Priority ranges already encode general group ordering.** Group 1 tasks (priority 1-50) run before Group 2 tasks (priority 51-100), and so on. Do NOT duplicate this ordering with explicit dependencies.

Only add cross-group dependencies for **hard technical blockers** — cases where a specific task in a later group literally cannot execute without a specific task in an earlier group being complete.

## All Tasks (Abbreviated)

{{ALL_TASKS}}

## Examples of Valid Cross-Group Dependencies

- "Implement User entity and migrations" (Entities group) → "Implement user authentication flow" (Auth group) — auth literally queries the User table
- "Deploy Kubernetes cluster" (Infrastructure group) → "Deploy content service" (Services group) — service needs a cluster to run on
- "Configure Stripe webhook endpoint" (Billing group) → "Implement subscription renewal handler" (Business Logic group) — handler processes Stripe webhook events

## Examples of INVALID Cross-Group Dependencies (Do NOT Add)

- Infrastructure group → any later group (priority already handles this)
- "Create database schema" → "Build API endpoints" (too vague — which schema? which endpoint?)
- Any dependency that merely restates the group ordering

## Instructions

### Step 1: Identify Hard Technical Blockers

Scan the task list for cases where:
- A task in a later group directly references output from a specific task in an earlier group
- A task requires a specific entity, service, or API endpoint that is created by a named task in another group
- A task cannot be meaningfully implemented or tested without a specific prerequisite from another group

### Step 2: Update Task Dependencies

For each cross-group dependency found, use `task_update`:

```javascript
mcp__dotbot__task_update({
  task_id: "task-XXXXXXXX",
  dependencies: ["existing-dep-1", "existing-dep-2", "new-cross-group-dep"]
})
```

**IMPORTANT:** Preserve any existing dependencies (from Phase 3a intra-group resolution) when adding new ones. Read the task first to get its current dependencies, then append.

### Step 3: Limit Scope

- Aim for at most **20-30 cross-group dependencies** across the entire project
- If you find yourself adding more, you're being too aggressive — step back and only keep the most critical ones
- When in doubt, do NOT add the dependency — let priority ordering handle it

## Output

Report:
- Total tasks reviewed
- Number of cross-group dependencies added
- List of each dependency added: "Task B (Group Y) depends on Task A (Group X)" with one-line justification
- Confirmation that existing intra-group dependencies were preserved
