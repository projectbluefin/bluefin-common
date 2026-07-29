---
name: factory-onboarding
version: "1.0"
last_updated: "2026-07-29"
id: factory-onboarding
one_line_purpose: Onboard repositories to the Project Bluefin factory model.
entry_point: docs/skills/factory-onboarding.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [factory, onboarding, setup]
description: >-
  How to onboard a repo into the Project Bluefin factory model. The
  self-improvement mandate, what agents must do, and what is banned. Load
  when setting up a new repo or auditing factory compliance.
metadata:
  type: reference
---

# Factory Onboarding

Project Bluefin is an agentic OS factory. Agents implement. Humans set direction and approve merges.

The factory gets smarter only if agents write back what they learn. Without that, every session starts from zero.

---

## Copyable Agent Onboarding

Use this sequence when an agent enters a factory repository:

1. Read the target repository's `AGENTS.md`. It is authoritative for local
   paths, ownership, build commands, and branch targets.
2. Read the target repository's `docs/SKILL.md` and, when published, its
   catalog. Load only the skill pages relevant to the task.
3. Resolve the Hive assignment and GitHub issue through their APIs. Verify the
   repository, issue, branch target, and requested scope before editing.
4. Load `projectbluefin/common` as the pinned shared-contract sidecar. Common
   supplies factory-wide rules; it never overrides the target repository's
   local authority.
5. Check ownership, canonical labels, credential rules, and named human gates.
   Do not simulate workflow state or bypass approval boundaries.
6. Create or update one compact task record containing the task ID, verified
   repository and issue, catalog refs, skills loaded, evidence, confidence,
   and learned facts.
7. Make the smallest scoped change, validate it with the target repository's
   existing checks, and hand off the task record and evidence.

Downstream repositories should link to this section rather than copying the
entire common policy tree. A missing catalog is degraded mode, not permission
to substitute arbitrary sibling checkouts or stale instructions.

## Every-Loop Self-Repair

Self-repair is part of every task loop, not an incident-only activity:

1. **Preflight:** verify repository, issue, catalog refs, branch target, and
   loaded skills.
2. **Detect:** treat stale, contradictory, missing, or failed guidance as a
   repair signal; do not silently fall back.
3. **Repair:** update the closest authoritative skill or contract when the
   repair is safe, in scope, and source-backed. Keep implementation changes
   separate from documentation learnings only when the repository contract
   requires it.
4. **Validate:** rerun the smallest relevant checks and confirm generated
   catalogs, links, ownership, and workflow boundaries still agree.
5. **Write back:** record durable learning, evidence, confidence, and any
   remaining gap in the task handoff. Route cross-repository learning to the
   owning repository or factory issue.
6. **Escalate:** stop for design, security, cross-repository breakage, merge,
   production, or unsupported API decisions. Autonomy repairs known failures;
   it does not manufacture approval.

Red flags are wrong-repository edits, stale catalog use, silent fallback,
repeated failure without a skill update, undocumented workarounds, and a task
that ends without evidence or durable learning.

## The Two-Output Rule

Every agent session produces two outputs:

1. **The work** — the PR, fix, or feature
2. **The learning** — what a future agent needs to know

Output 1 without Output 2 = factory does not improve.

The learning goes in `docs/skills/` — the same PR, not a follow-up.

---

## What Is Banned

These patterns actively harm the factory. Delete them when found.

**Changelog files** (`IMPROVEMENTS.md`, `CHANGELOG.md`, `CHANGES.md`, `SESSION.md`, etc.)
Agents append to them instead of updating skill files. The result: a stale changelog, skill files that never get updated. **Delete on sight.**

**"Append here" instructions**
Any doc saying "append when you ship something" is a hallucination magnet. Route to `docs/skills/<file>.md` instead.

**Session logs committed to the repo** (`NOTES.md`, `PLAN.md`, `TODO.md`, progress files)
These become stale context that misleads every future agent. Session state lives in the agent's session folder only, never committed.

---

## What a Factory Repo Needs

### `docs/skills/`

Every repo needs a `docs/skills/` directory. This is the knowledge base. Agents read it; agents update it.

Minimum files:
- `skill-improvement.md` — the two-output rule adapted for this repo
- `docs/SKILL.md` — task→skill router and index

Reference: [`projectbluefin/common/docs/skills/`](https://github.com/projectbluefin/common/blob/main/docs/skills/)

### `skill-drift.yml` CI check — currently non-functional, verify before wiring up

`projectbluefin/actions/.github/workflows/skill-drift-check.yml` — the reusable workflow this check calls — is presently a **no-op stub** (real logic removed in `actions@001ae97`, replaced with a compatibility stub in `actions@a7c230c`). It always succeeds without inspecting any changed paths. Do not wire this up expecting it to actually warn on anything; a passing run currently proves nothing. Full detail: [`skill-drift.md`](./skill-drift.md#current-status-non-functional).

If you still want the placeholder wired up for when the reusable workflow is rebuilt, the shape is:

```yaml
name: Skill Drift

on:
  pull_request:
    branches: [main]

permissions:
  contents: read
  pull-requests: read

jobs:
  skill-drift:
    uses: projectbluefin/actions/.github/workflows/skill-drift-check.yml@v1
    with:
      code-paths: '[".github/workflows/**", "Justfile"]'  # adapt to your repo
      skill-paths: '["docs/skills/**", "docs/*.md", "AGENTS.md"]'
```

Until `actions` restores real logic, rely on the `skill-improvement.md` self-repair loop (manual, agent-enforced) instead of this CI check for enforcement — see how `common` itself handles this in [`ci-tooling.md`](./ci-tooling.md#skill-drift-detection): it deliberately does not run this workflow at all.

Adjust `code-paths` to match your repo's implementation files. Treat warnings as hard requirements.

### `AGENTS.md` — self-improvement section

Every factory repo's `AGENTS.md` must state the two-output rule and the banned anti-patterns explicitly. Agents read `AGENTS.md` first. If it is not there, agents will not do it.

Minimum block to include:

```markdown
## Self-Improvement

Every session: ship the work AND update the relevant skill file in `docs/skills/`.
Same PR. Not a follow-up.

Banned:
- No changelog files. Delete IMPROVEMENTS.md, CHANGELOG.md, SESSION.md if found.
- No session notes committed to the repo.
- No "append here" docs. Route to docs/skills/ instead.

Before marking work done:
- [ ] Discovered a workaround, pattern, or convention?
- [ ] Skill file updated (or created)?
- [ ] Committed in this same PR?
```

---

## Done When

- [ ] `docs/skills/` exists with `skill-improvement.md` and `docs/SKILL.md` task router
- [ ] `skill-drift.yml` wired and passing
- [ ] `AGENTS.md` includes self-improvement mandate and banned list
- [ ] Downstream onboarding points agents to local authority plus common as a
      shared sidecar
- [ ] Every task loop includes preflight, self-repair, validation, and
      durable learning
- [ ] No changelog files in the repo

---

## Cross-Repo Patterns

Factory-wide learning → open an issue in `projectbluefin/common` with the
learning, affected component, and evidence in its body.
Never touch `ublue-os/*`. Tell the human to report upstream manually.
