---
name: pr-review
version: "3.0"
last_updated: "2026-08-06"
id: pr-review
one_line_purpose: Run human-decides, agent-lands backlog review in batches of five.
entry_point: docs/skills/pr-review.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [review, merge, triage, backlog]
description: >-
  Human-decides, agent-lands PR and issue backlog review. Assemble a 5-item
  dossier, collect per-item human verdicts, stage gh commands, land on confirm.
  Use when reviewing the PR queue or triaging the issue backlog.
metadata:
  type: procedure
---

# Backlog Review — Human Decides, Agent Lands

The agent assembles facts and executes commands. The human makes every
approval, merge, close, and label decision. No exceptions.

## Contents

- [When to Use](#when-to-use)
- [Core Process](#core-process)
- [Issue Triage Sweep](#issue-triage-sweep)
- [Blast Radius Map](#blast-radius-map)
- [Merge Queue Defaults](#merge-queue-defaults)
- [Worked Example](#worked-example)
- [Red Flags](#red-flags)
- [Verification](#verification)
- [See Also](#see-also)

---

## When to Use

- Reviewing the open PR queue.
- Triaging the open issue backlog.
- A maintainer asks to "work through the backlog."

## Core Process

The loop: **dossier → verdict → stage → land.**

### 1 — Dossier

Assemble exactly **5** PRs (or issues). Present each as a one-screen card.

**Card fields** (all required):

| Field | Source |
|---|---|
| Number, title, author | `gh pr view` |
| Age | `createdAt` → human-readable delta |
| Size | `+additions / -deletions` |
| Files touched | file list from API |
| Blast radius | see [Blast Radius Map](#blast-radius-map) |
| CI status | `gh pr checks` — real names and pass/fail |
| Mergeable state | `MERGEABLE` / `CONFLICTING` / `UNKNOWN` |
| Linked issue | parsed from body or `closingIssuesReferences` |
| Competing / duplicate PRs | same files or same linked issue |
| Summary | ONE factual sentence — what the change does |
| Effort | `trivial` · `small` · `needs-real-attention` · `blocked-on-something` |

> ⚠️ The agent classifies EFFORT but **never** states a verdict, recommendation,
> or approval judgment. Report facts only.

### 2 — Verdict

Prompt the human **per PR, one at a time** (not a batch line).

PR verdict vocabulary:

| Verdict | Effect |
|---|---|
| `merge` | Squash-merge via merge queue |
| `close` | Close with the human’s stated reason |
| `defer` | Leave open, move to next |
| `rebase` | Update branch, re-present later |
| `changes` | Request changes with the human’s exact words |
| `open` | Show the full diff before deciding |
| `skip` | Move to next, no action |

### 3 — Stage

After all 5 verdicts, print the **complete action plan** as exact `gh`
commands, then ask: **"Confirm? (yes / edit / abort)"**

Nothing is written before the human confirms.

### 4 — Land

On confirm, execute the batch. Report per-PR outcome (succeeded / failed /
needs follow-up). If any command fails, report the error and continue.

---

## Issue Triage Sweep

Same dossier → verdict → stage → land loop, with issue verdicts:

| Verdict | Effect |
|---|---|
| `close` | Close with the human’s stated reason |
| `label <name>` | Apply a label — only the 7 canonical labels per [label-workflow](label-workflow.md) |
| `assign` | Assign to a user or bot |
| `dup <#>` | Close as duplicate, link to the original |
| `wrongrepo <repo>` | Transfer or close with redirect |
| `needsinfo` | Comment requesting more information |
| `defer` | Leave open |

---

## Blast Radius Map

| Path pattern | Affects | Fast-lane eligible? |
|---|---|---|
| `system_files/shared/` | bluefin + bluefin-lts + dakota | **Never** |
| `system_files/bluefin/` | GNOME / Bluefin only | No |
| `system_files/nvidia/` | NVIDIA overlay | No |
| `.github/workflows/` | CI pipeline | No |
| `Containerfile` | ALL variants | No |
| `docs/**`, `AGENTS.md` | Documentation only | N/A (doc-only push) |
| `tests/**` | Test suite only | N/A |

> ⚠️ `system_files/shared/` is never eligible for any fast lane regardless of
> diff size. A break there breaks bluefin, bluefin-lts, AND dakota simultaneously.

---

## Merge Queue Defaults

The merge queue on `main` is squash-only (`grouping_strategy: ALLGREEN`).
Required checks: `validate`, `Build and push image (x86_64)`,
`Build and push image (aarch64)`.

Default landing command:

```bash
# Squash-merge via the merge queue (default)
gh pr merge <N> --squash --auto --delete-branch
```

`--admin` bypasses the queue and merges immediately. It requires **explicit
human instruction** per PR — never default to it.

```bash
# Admin merge — ONLY when the human explicitly says so
gh pr merge <N> --squash --admin --delete-branch
```

Fork PRs cannot be rebased via `gh pr update-branch` — see
[queue-dashboard.md](queue-dashboard.md) for the manual git rebase pattern.

---

## Worked Example

> Based on the open backlog as of 2026-08-06.

### Dossier (batch 1 of 2)

**1 / 5 — PR #936** `fix(report): preserve external queue preferences`
Author: joshyorko · Age: 2h · Size: +80 / -5 · Effort: **small**
Files: `.github/workflows/unit-tests.yml`, `Justfile`, `docs/SKILL.md`,
`system_files/bluefin/usr/libexec/bonedigger-report`,
`tests/test_bonedigger_report.bats`
Blast radius: bluefin only + CI + docs
CI: pending · Mergeable: yes · Linked issue: —
Summary: Preserves caller-supplied queue preference in the bonedigger report script.

**2 / 5 — PR #934** `fix: guard ublue-fastfetch with command -v check`
Author: kylerankin · Age: 1d · Size: +5 / -0 · Effort: **trivial**
Files: `system_files/shared/usr/bin/ublue-fastfetch`
Blast radius: **ALL variants** (`system_files/shared/`)
CI: pending · Mergeable: yes
Summary: Adds a `command -v fastfetch` guard so the script exits cleanly.

**3 / 5 — PR #933** `fix(sec): add sigstoreSigned policy for ghcr.io/projectbluefin`
Author: hanthor · Age: 1d · Size: +31 / -0 · Effort: **needs-real-attention**
Files: `system_files/shared/etc/containers/policy.json` + signing certs
Blast radius: **ALL variants** — security policy
CI: pending · Mergeable: yes · Label: ` 3-human-queue`
Summary: Adds sigstore signature verification for projectbluefin images.

**4 / 5 — PR #932** `fix: add consistent bootc sudo policy`
Author: castrojo · Age: 1d · Size: +1 / -0 · Effort: **trivial**
Files: `system_files/shared/etc/sudoers.d/001-bootc`
Blast radius: **ALL variants**
CI: pending · Mergeable: yes
Summary: Adds a sudoers drop-in for consistent bootc sudo policy.

**5 / 5 — PR #926** `[quality] add BATS regression coverage for theming hook`
Author: kubestellar-hive [bot] · Age: 3d · Size: +92 / -0 · Effort: **small**
Files: `Justfile`, `docs/TESTING.md`, `tests/test_theming_hook.bats`
Blast radius: tests + docs only
CI: pending · Mergeable: yes
Summary: Adds BATS test coverage for the theming setup hook.

---

### Per-PR verdict prompts

```
PR #936 — fix(report): preserve external queue preferences
Verdict? (merge / close / defer / rebase / changes / open / skip)
> merge

PR #934 — fix: guard ublue-fastfetch with command -v check
Verdict? (merge / close / defer / rebase / changes / open / skip)
> open
[agent shows diff]
> merge

PR #933 — fix(sec): add sigstoreSigned policy
Verdict? (merge / close / defer / rebase / changes / open / skip)
> changes: Split the cert and rekor key into their own commit for auditability.

PR #932 — fix: add consistent bootc sudo policy
Verdict? (merge / close / defer / rebase / changes / open / skip)
> merge

PR #926 — [quality] add BATS regression coverage for theming hook
Verdict? (merge / close / defer / rebase / changes / open / skip)
> merge
```

### Staged action plan

```bash
## Action plan — batch 1

# PR #936 — merge (squash via queue)
gh pr merge 936 --squash --auto --delete-branch

# PR #934 — merge (squash via queue)
gh pr merge 934 --squash --auto --delete-branch

# PR #933 — request changes
gh pr review 933 --request-changes --body "Split the cert and rekor key into their own commit for auditability."

# PR #932 — merge (squash via queue)
gh pr merge 932 --squash --auto --delete-branch

# PR #926 — merge (squash via queue)
gh pr merge 926 --squash --auto --delete-branch
```

```
Confirm? (yes / edit / abort)
> yes
```

### Landing report

| PR | Action | Result |
|---|---|---|
| #936 | merge | ✅ auto-merge enabled |
| #934 | merge | ✅ auto-merge enabled |
| #933 | changes | ✅ review posted |
| #932 | merge | ✅ auto-merge enabled |
| #926 | merge | ✅ auto-merge enabled |

---

## Red Flags

- Agent states an opinion on whether a PR should be merged.
- Agent approves, merges, closes, or labels without an explicit human verdict.
- `--admin` merge used without explicit human instruction.
- `system_files/shared/` change treated as trivial or fast-laned.
- Batch executed before the human confirms the staged plan.

## Verification

- [ ] Every `gh pr merge` / `gh pr close` was preceded by an explicit human verdict.
- [ ] No approval judgment or recommendation appears in dossier cards.
- [ ] `--admin` was used only when the human explicitly said so.
- [ ] `system_files/shared/` PRs were flagged as ALL-variant blast radius.
- [ ] The four [human decision gates](human-gates.md) were respected.
- [ ] Staged action plan was printed and confirmed before any writes.

## See Also

- [human-gates.md](human-gates.md) — the four human decision gates
- [label-workflow.md](label-workflow.md) — canonical label lifecycle
- [queue-dashboard.md](queue-dashboard.md) — merge queue config and admin merge
- [governance.md](governance.md) — branch protection and ownership
- [shell-scripts.md](shell-scripts.md) — shell review patterns and bats testing
- [ci-tooling.md](ci-tooling.md) — CI workflow review and SHA pinning
- [oem-hardware-hooks.md](oem-hardware-hooks.md) — OEM hook review
- [dconf-consistency.md](dconf-consistency.md) — dconf override + lock review
- [lab-testing/SKILL.md](lab-testing/SKILL.md) — lab verification
