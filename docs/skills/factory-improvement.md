---
name: factory-improvement
version: "1.0"
last_updated: "2026-06-23"
id: factory-improvement
one_line_purpose: Audit and propose factory self-improvement automation.
entry_point: docs/skills/factory-improvement.md
category: meta
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [factory, automation, improvement]
description: >-
  Self-improving factory loop for projectbluefin. Use when identifying
  automation gaps, proposing workflows, or auditing ACMM maturity.
metadata:
  type: reference
---

# Factory Improvement — Self-Improving Loop

## Contents
- [When to Use](#when-to-use)
- [When NOT to Use](#when-not-to-use)
- [Mission](#mission)
- [Human Gates — Intentional and Non-Negotiable](#human-gates--intentional-and-non-negotiable)
- [The Improvement Loop](#the-improvement-loop)
- [Pipeline Uniformity Checklist](#pipeline-uniformity-checklist)
- [E2E Gate Matrix](#e2e-gate-matrix)
- [Finding Open Gaps](#finding-open-gaps)
- [What "Done" Looks Like](#what-done-looks-like)

---

## When to Use

- Dedicated "improve the factory" sessions
- After an architectural review surfaces gaps
- Onboarding a new repo into the factory standard
- Quarterly health check: design vs. reality drift

## When NOT to Use

- Fixing a specific bug (use the repo's AGENTS.md + relevant skill)
- Reviewing a single PR (use `hive-review` or `pr-review`)
- Active incident response — fix the incident first, then run this loop

---

## Mission

**Full automation of everything that does not require a human judgment call.**

The factory should be self-healing: issues flow through the pipeline, agents handle
the mechanical work, and humans make only the decisions requiring accountability,
context, or trust. Every manual step that *could* be automated is a reliability tax.

---

## Human Gates — Intentional and Non-Negotiable

Never automate these. Never propose automating them without explicit maintainer approval:

| Gate | Why it must be human |
|---|---|
| Admitting an issue to a queue (`3-human-queue` / `3-clanker-queue`) | Prioritization judgment; agent scope assignment |
| PR merge approval (1 human reviewer per CODEOWNERS) | Accountability; trust for org-critical changes |
| Release blocker calls during a promotion window | Release impact judgment |
| Production promotion decisions (Tuesday 06:00 UTC, N=7 floor) | Final go/no-go for user-facing changes — automation handles the gate, but human review of the e2e results is the last word |
| Reassigning or closing a stale PR | Judgment on abandoned vs. still-active work |
| Any write or automated action to `ublue-os/*` namespace | Absolute prohibition — includes issues, PRs, reports, webhooks, dispatch. Reads only. |

Everything else is automatable.

---

## The Improvement Loop

```
MEASURE → TRIAGE → IMPLEMENT → CAPTURE → VERIFY → LOOP
```

### MEASURE

```bash
~/src/hive-status

# Everything awaiting triage across the factory
gh search issues --label "1-triage" --owner projectbluefin --state open \
  --json number,title,repository

# Work already admitted to the agent queue
gh search issues --label "3-clanker-queue" --owner projectbluefin --state open \
  --json number,title,repository
```

### TRIAGE

For each open gap:
- Human gate? → **SKIP** (log it, do not touch)
- Doc gap? → **IMMEDIATE** (cheapest fix, push directly to main)
- CI/tooling gap? → file as a GitHub issue and let triage route it
- Cross-repo gap? → assess blast radius before acting

> Do **not** self-apply a queue label. Triage and queue admission are human
> decisions; agents file the issue and stop.

### IMPLEMENT

- Work highest-blast-radius gap first
- Prefer: doc fix > CI change > code change
- Max 4 open PRs at once
- Always `just check` + `pre-commit run --all-files` before commit

### CAPTURE

When you discover a gap:

1. File a GitHub issue in `projectbluefin/common`
2. Write a clear description — what is broken, what the fix looks like, whether it's automatable
3. Stop. Do not self-apply a queue label — triage and queue admission are human decisions

```bash
# Example: file a factory CI gap
gh issue create --repo projectbluefin/common \
  --title "ci: pre-commit not wired in testsuite" \
  --body "..."
```

### VERIFY

Would a fresh agent reading only the skills avoid the gap just closed?
If no → the skill is still incomplete.

---

## Pipeline Uniformity Checklist

Each factory repo (`common`, `bluefin`, `bluefin-lts`, `dakota`, `testsuite`, `actions`)
must have ALL of:

| Requirement | Check command |
|---|---|
| `AGENTS.md` present | `gh api repos/projectbluefin/{repo}/contents/AGENTS.md` |
| `bonedigger.yml` wired (image repos only) | `gh api repos/projectbluefin/{repo}/contents/.github/workflows/bonedigger.yml` |
| Hive labels present | `gh label list --repo projectbluefin/{repo} \| grep hive` |
| pre-commit config present | `gh api repos/projectbluefin/{repo}/contents/.pre-commit-config.yaml` |
| Squash-only merge | `gh repo view projectbluefin/{repo} --json squashMergeAllowed,mergeCommitAllowed` |

Missing any row = a gap to close.

---

## E2E Gate Matrix

| Repo | Pre-merge | Post-merge | Promotion |
|---|---|---|---|
| common | `pr-e2e.yml` (composed + common suite) | `e2e.yml` | `promotion-candidate-e2e.yml` |
| bluefin | PR smoke gate | post-merge common suite | Tuesday 06:00 UTC, N=7 floor, broad e2e suite |
| bluefin-lts | PR validation (`pr-testsuite.yml`) + advisory e2e (`pr-e2e.yml`) | post-merge e2e | upgrade-test + failure issue reporting |
| dakota | BST graph validation (`bst show`) | post-merge publish gate | Tuesday 06:00 UTC, N=7 floor, smoke+common e2e suite |

Gaps in this matrix = testing blind spots. File issues for missing gates.

---

## Documentation Single-Source-of-Truth

Each rule must exist in exactly ONE location. Other files should have a one-line pointer.

| Rule | Canonical location |
|---|---|
| ublue-os prohibition | `common/AGENTS.md` |
| Issue lifecycle table | `docs/skills/label-workflow.md` |
| PR comment policy | `docs/factory/agentic-model.md` |
| Branch targets by repo | `docs/factory/agentic-model.md` |
| Session start ritual | `common/AGENTS.md` (+ pointer in agentic-model.md) |
| Task→skill routing | `docs/SKILL.md` |

---

## Finding Open Gaps

Factory gaps are tracked as GitHub issues. Do not maintain gap lists in this doc — they drift. Always query GitHub for the current state:

```bash
# Everything awaiting triage
gh search issues --label "1-triage" --owner projectbluefin --state open \
  --json number,title,repository

# Work admitted to the agent queue
gh search issues --label "3-clanker-queue" --owner projectbluefin --state open \
  --json number,title,repository
```

---

## What "Done" Looks Like

- [ ] Every factory repo has identical infrastructure (AGENTS.md, the seven labels, pre-commit, squash-only)
- [ ] Every pipeline stage has a gate: pre-merge CI, post-merge e2e, promotion smoke
- [ ] All rules exist in exactly one canonical location with one-line pointers elsewhere
- [ ] Renovate is running across all repos
- [ ] No known AI blindspot (ACMM audit) is unmitigated
- [ ] Only the human gates listed above remain manual
- [ ] ISO rebuilds are event-driven (triggered by stable promotion, not manual dispatch)
- [ ] Supply chain: keyless signing + SBOM + SLSA L2 provenance on all image builds
- [ ] Self-healing: retry + token health check on all workflows with external dependencies

---

## Automation Audit — completed 2026-06-11

All 7 automation phases deployed. The audit directory has been removed. Key outcomes:

| Measure | Result |
|---|---|
| Workflow automation | ~97% (124 workflows, 7 repos) |
| Human gates | 4 intentional (promotion review, actions merge, priority assignment, stale PR unclaim) |
| Supply chain | Keyless OIDC + SBOM + SLSA L2 live ([common#595](https://github.com/projectbluefin/common/pull/595)) |
| C1 reusable-promote | dakota ✅, bluefin-lts ✅, **bluefin pending** ([common#584](https://github.com/projectbluefin/common/issues/584)) |

---

## Known CI Pitfalls (2026-06-11)

Three patterns that have caused silent CI failures or `startup_failure` across factory repos. See [`docs/skills/ci-pitfalls.md`](ci-pitfalls.md) for full detail and code examples.

| Pitfall | Symptom | Fix |
|---|---|---|
| **Consumer PR colon format** | `check-consumer-contract.yml` fails silently | PR body must use `Consumer PR: <URL>` (colon format) — NOT a Markdown heading |
| **Caller permissions starvation** | Reusable workflow job shows `startup_failure` with no output | Caller `permissions:` block must include the union of all permissions the reusable jobs need |
| **`workflow_run` name mismatch** | Post-merge e2e gate always skips | `workflow_run.workflows:` must match the **exact** `name:` field of the target YAML — verify it produces the artifact being tested |

---

## Cross-Repo Dispatch Patterns

When dispatching workflows across repos (e.g., `execute-release.yml` → `iso`), `GITHUB_TOKEN` **cannot** create `repository_dispatch` events on other repositories. Use a GitHub App installation token:

```yaml
- name: Generate dispatch token
  id: app-token
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.ISO_DISPATCH_APP_ID }}
    private-key: ${{ secrets.ISO_DISPATCH_PRIVATE_KEY }}
    repositories: iso

- name: Dispatch
  env:
    GH_TOKEN: ${{ steps.app-token.outputs.token }}
  run: gh api repos/projectbluefin/iso/dispatches -f event_type="stable-promoted" ...
```

Never use `secrets.GITHUB_TOKEN` for cross-repo dispatch — it will silently fail (GitHub returns 404, not 403).

---

## Session Close

After each improvement session:

1. For each gap discovered: file a GitHub issue (see CAPTURE above)
2. For significant improvements shipped: update the relevant skill file in `docs/skills/`

Do **not** maintain gap lists or changelogs in this skill file or anywhere in the repo. GitHub issues are the live backlog; `docs/skills/` is the knowledge base.

This skill is the operating procedure for the improvement loop, not the backlog itself.
