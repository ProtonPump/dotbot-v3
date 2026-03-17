---
name: Proposal ADR Interview
description: Multi-round interview to resolve unresolved ADRs (Proposed, Open, Conflict) from the project proposal
version: 1.0
---

# Proposal ADR Interview

You are conducting a requirements interview to resolve unresolved Architecture Decision Records (ADRs) from a project proposal. The proposal has already been analyzed — accepted decisions are imported, but some ADRs remain unresolved and need human input before implementation can begin.

## Context Provided

- **User's prompt**: The path to the project proposal repository
- **Previous Q&A rounds**: Answers from earlier interview rounds (if any)

## Your Task

### Step 1: Read Unresolved ADRs

Read the unresolved ADRs file:
```
.bot/workspace/product/unresolved-adrs.json
```

This file contains ADRs with status Proposed, Open, or Conflict. Each ADR includes:
- `adr_id` — the original ADR identifier (e.g., ADR-0037)
- `title` — what the decision is about
- `status` — Proposed (has a recommendation), Open (no recommendation yet), or Conflict (contradictory information)
- `context` — why this decision matters
- `decision_drivers` — criteria for making the decision
- `options_considered` — evaluated options with pros and cons
- `decision` — the current recommendation (if Proposed) or blank (if Open/Conflict)
- `consequences` — what follows from each option

### Step 2: Also Read Previous Answers

If previous Q&A rounds exist (provided below), check which ADRs have already been resolved. Do not re-ask resolved questions.

### Step 3: Decide

Review all unresolved ADRs and previous answers. Then decide:

#### Decision A: More questions needed

If there are unresolved ADRs remaining, write questions to `.bot/workspace/product/clarification-questions.json`.

**For each unresolved ADR, generate a question with options:**

- **For Proposed ADRs** (has a recommendation): Present the recommendation as Option A, alternatives as B/C/etc. Set `recommendation: "A"`.
- **For Open ADRs** (no recommendation): Present all evaluated options as A/B/C. If you can infer a recommendation from the context, set it. Otherwise omit `recommendation`.
- **For Conflict ADRs**: Present the conflicting positions as options. Explain the contradiction in the `context` field. Let the user resolve it.

**Derive options from the ADR's `options_considered` section.** Each option should use the option name as the label and summarize the pros/cons as the rationale. If the ADR has no options_considered, create reasonable options based on the context and decision drivers.

**Always include a final option** for custom/alternative input (e.g., "Other — provide your own answer").

Write the file with this structure:

```json
{
  "questions": [
    {
      "id": "q1",
      "question": "Clear, specific question text derived from the ADR title and context",
      "context": "Why this matters — from ADR context and decision drivers. Include the ADR ID for reference.",
      "options": [
        { "key": "A", "label": "Recommended option name", "rationale": "Pros: ... Cons: ..." },
        { "key": "B", "label": "Alternative option name", "rationale": "Pros: ... Cons: ..." },
        { "key": "C", "label": "Another alternative", "rationale": "Pros: ... Cons: ..." },
        { "key": "D", "label": "Other — provide your own answer", "rationale": "If none of the above options fit your needs" }
      ],
      "recommendation": "A"
    }
  ]
}
```

Rules for questions:
- Each question must have 2-5 options (A through E), derived from the ADR's evaluated options
- Option A should be the recommended choice (for Proposed ADRs, use the ADR's own recommendation)
- Always include a "Other" option as the last choice
- The `context` field should reference the ADR ID (e.g., "ADR-0037: CMS Platform Selection")
- Group related ADRs into a single question if they are tightly coupled (e.g., CMS selection and editorial workflow are linked)
- No artificial limit on question count — ask as many as needed to resolve all unresolved ADRs
- If previous answers revealed new questions or changed the context for remaining ADRs, address those too

#### Decision B: All clear

If all unresolved ADRs have been resolved (through Q&A rounds or because the user skipped remaining questions), write `.bot/workspace/product/interview-summary.md` instead.

The summary must contain:

1. **For each Q&A pair** (from all rounds):
   - The ADR ID and title
   - The user's **verbatim answer**
   - Your **expanded interpretation**: what the answer means for the decision, and what should be recorded as the accepted Decision

2. **Remaining unresolved ADRs** (if user skipped): List ADRs that were not resolved. Note that these will surface as `needs_interview` flags during per-task analysis.

3. **Synthesis section**: Summary of all resolved decisions and their combined impact on the project architecture and scope.

## Critical Rules

- Write **exactly one file**: either `clarification-questions.json` OR `interview-summary.md`
- **NEVER** write both files in the same round
- Do NOT create any other files
- Do NOT use task management or decision management tools — decisions will be created from answers in a later phase
- Focus on the unresolved ADRs — do not ask about topics already covered by accepted decisions
