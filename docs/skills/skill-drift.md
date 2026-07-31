---
name: skill-drift
version: "1.0"
last_updated: "2026-06-23"
id: skill-drift
one_line_purpose: Decide if a PR needs a skill-doc update under the drift waiver process.
entry_point: docs/skills/skill-drift.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [skills, drift, ci]
description: >-
  Skill-drift CI check and waiver process. Use when a PR changes
  implementation files and you need to decide if a skill update is required.
metadata:
  type: reference
---

# Skill Drift

`skill-drift.yml` is meant to warn when a PR changes implementation files without updating the matching skill documentation, keeping agent-facing docs in sync with real repo behavior while the implementation context is still fresh. **`common` does not run this workflow at all** — see [`ci-tooling.md`](./ci-tooling.md#skill-drift-detection) for why. This page documents the check as it exists in the other factory repos that do wire it up (bluefin, bluefin-lts, dakota, knuckle, testsuite).

The mandate for *why* you must write skill updates is in [`skill-improvement.md`](./skill-improvement.md).

---

## Current status: non-functional

**`projectbluefin/actions`' `skill-drift-check.yml` reusable workflow is currently a no-op stub.** Its real drift-detection logic was removed (`actions@001ae97 chore: remove skill-drift and skill-audit workflows`) and later replaced with a stub kept only for caller compatibility (`actions@a7c230c fix: restore skill-drift-check.yml as a no-op stub for consumer compat`). The stub's own job step just echoes `"Skill drift check removed. Delete skill-drift.yml from consumer repo."` and exits successfully — it does not inspect changed paths and cannot warn on anything.

Practical effect: every repo below that still has a local `skill-drift.yml` calling `projectbluefin/actions/.github/workflows/skill-drift-check.yml@v1` (or a pinned SHA) is currently getting a silent, always-green no-op on every PR. **Do not treat "no skill-drift warning" as evidence a skill update wasn't needed.** The self-repair/write-back discipline in [`skill-improvement.md`](./skill-improvement.md) is the only thing actually enforcing this right now — CI is not.

Until the reusable workflow is rebuilt with real logic (or every consumer repo removes its now-decorative `skill-drift.yml` per the stub's own comment), the rest of this page describes the *intended design*, not current behavior.

### How it was designed to work

```
PR opened
  └─ extract changed files
       ├─ match against code-paths
       └─ if code-paths hit and no skill-paths hit → WARN
```

The design was always advisory (warn, don't block merge). That intent is unchanged by the stub — there is simply nothing running it right now.

---

## Path mapping by repo

Repos below opted in by adding their own `.github/workflows/skill-drift.yml` calling the shared workflow. `common` is intentionally not listed — it does not run this check (see [`ci-tooling.md`](./ci-tooling.md#skill-drift-detection)).

| Repo | code-paths | skill-paths |
|---|---|---|
| bluefin | `.github/workflows/**`, `build_files/**`, `Justfile`, `recipes/**` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| bluefin-lts | `.github/workflows/**`, `build_files/**`, `Justfile` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| dakota | `.github/workflows/**`, `build_files/**`, `Justfile`, `elements/**` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| knuckle | `.github/workflows/**`, `cmd/**`, `internal/**`, `Justfile`, `scripts/**` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |
| testsuite | `.github/workflows/**`, `.github/actions/**`, `tests/**`, `scripts/**` | `docs/skills/**`, `docs/*.md`, `AGENTS.md` |

Each repo's `skill-drift.yml` calls the reusable `projectbluefin/actions/.github/workflows/skill-drift-check.yml`, currently the no-op stub described above.

---

## Code path → skill file mapping

Use this when the check fires and you need to know which skill to update:

| Changed path | Update this skill |
|---|---|
| `.github/workflows/build.yml`, `build.yml` | `bluefin-build.md` or `bluefin-ci.md` |
| `.github/workflows/e2e*.yml`, test configs | `e2e-ci.md` |
| `.github/workflows/lifecycle*.yml` | `label-workflow.md` |
| `.github/workflows/skill-drift.yml` | `skill-drift.md` (this file) |
| `.github/workflows/release.yml` | `release-promotion.md` |
| `system_files/**` | `submodule-boundary.md` or `dconf-consistency.md` |
| `Justfile` | whichever skill owns the changed recipe |
| `Containerfile` | `bluefin-build.md` |
| `elements/**` (dakota) | matching `dakota-*.md` skill |
| `.github/CODEOWNERS` | `governance.md` |

Not sure? Check `docs/SKILL.md` for the task→skill router.

---

## What counts as a satisfying update

A passing update must:
- Name the file, workflow, hook, command, or path that changed
- State the new rule, behavior, or expectation
- Explain what an agent should now do differently

**Passing:** "Added `elements/**` to code-paths in skill-drift.yml; dakota element changes now trigger skill-drift warnings. Update matching `dakota-*.md` when changing elements."

**Failing:** rewrapping text, adding unrelated notes, or touching any markdown file without explaining the implementation change.

---

## Waiver process

Moot while the workflow is a no-op stub — nothing is currently firing to waive. Kept below for when the reusable workflow is rebuilt.

For refactoring changes with no functional impact:

1. Add to your PR description:
   ```markdown
   ## Skill drift waiver
   Changed: `.github/workflows/build.yml`
   Reason: Internal variable rename only — no behavior change, no operator impact.
   ```
2. A maintainer can override the check. Do not self-waive.

---

## Common failure modes

- Changing a workflow and forgetting to update docs
- Updating the wrong skill file for the behavior that changed
- Adding a placeholder doc that does not explain the change
- Assuming advisory = optional
- **Assuming a green `skill-drift.yml` run means a skill update wasn't needed** — right now it means nothing, since the shared workflow is a no-op stub (see "Current status" above)
