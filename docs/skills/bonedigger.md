---
name: bonedigger
version: "1.0"
last_updated: "2026-07-30"
id: bonedigger
one_line_purpose: Operate bonedigger and kubestellar-bot issue/report automation.
entry_point: docs/skills/bonedigger.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [bonedigger, triage, automation]
description: >-
  bonedigger + kubestellar-bot lifecycle automation. Use when working on
  ujust report, issue lifecycle, priority escalation, or how fixes ship back
  to images.
metadata:
  type: reference
---

# bonedigger & kubestellar-bot

**Repo:** https://github.com/projectbluefin/bonedigger

## When to Use

Use when changing `ujust report`, its confirmation flow, bonedigger intake, or
the labels that route user reports into the factory.

## When Not to Use

Do not use this skill for generic GitHub issue triage, unrelated GitHub CLI
configuration, or lifecycle automation owned by `projectbluefin/actions`.

## Core Process

1. Keep collection local, targeted, bounded, and redacted.
2. Route bugs from the booted image and feature requests to common.
3. Preview the exact public payload and require consent before any upload.
4. Submit with authenticated `gh`, preserve failures as resumable drafts, and
   verify the target, queue label, and receipt.

## The full loop

bonedigger and kubestellar-bot together form the closed improvement loop that drives Bluefin 2.0:

```
user runs ujust report
  └─ bonedigger agent collects selected diagnostics
       └─ scrubs PII on-device and previews the payload
            └─ creates a structured issue in the target image repo
                 └─ lifecycle bot moves issue through pipeline
                      └─ kubestellar-bot picks up status/queued issue
                           └─ dispatches agent to implement fix
                                └─ PR shipped back to image repo
                                     └─ merged → better OS
                                          └─ better bonedigger
                                               └─ loop
```

## bonedigger - what it does

bonedigger has two functions:

1. **ujust report detection** - when an issue is filed via `ujust report` on a live system, bonedigger detects the diagnostic signature and sets `source:ujust-report`
2. **Priority auto-escalation** - tracks `ujust confirm` counts and escalates:
   - 3+ confirms → adds `priority/p1`
   - 5+ confirms → adds `priority/p0`

**Packaging note:** in common, keep `ujust report` as a thin recipe wrapper in
`system_files/bluefin/usr/share/ublue-os/just/60-bonedigger.just` and put the
real shell implementation in `/usr/libexec/bonedigger-report`. Keep the
`BONEDIGGER_VERSION` line in the Justfile because Renovate watches that path.

### Creating a report

`ujust report` begins by asking the user's intent: report a bug, get help,
request a feature, or confirm an existing issue. Help points to Bluefin
Discussions without creating an issue. Feature requests always target
`projectbluefin/common`; bugs use the image mapping below and show that target
before collecting data.

Bug reports collect a short title, description, and reproduction steps, then
offer zero or more bounded smart-log profiles: desktop/graphics, sleep/crash,
update/boot, networking, and Flatpak/application. The baseline report is at
most 64 KiB; each profile is at most 500 KiB and all selected profiles total
at most 2 MiB. Collection is an allowlist of targeted commands, and journal
output uses the on-device redaction functions. OTel capture is not part of this
flow.

Every payload is previewed locally. Submission requires explicit consent,
uses `gh issue create` rather than a browser form, and offers final-submission
queue preferences: `3-clanker-queue`, `3-human-queue`, or no queue label.
Selected smart logs are
published to a public gist only after that preview and consent. `gh` is
required and authenticated; if it is absent, the user can consent to
`brew install gh`. Failed or declined submissions retain a draft and print its
exact `ujust report --resume …` command. The visible `ujust report` report
heading remains the intake compatibility marker rather than making issue
creation depend on a `source:ujust-report` label.

### Confirm an existing issue

Use `ujust report --confirm <issue-number-or-url>` when the current system is
affected by an existing issue. This mode previews and posts a lightweight
fingerprint (image, version/digest, kernel, architecture, and failed units)
with `gh issue comment`. It does not collect OTel data, create a gist, or
derive an identifier from `machine-id`. A positive issue number uses the
booted image's normal routing: Bluefin LTS goes to
`projectbluefin/bluefin-lts`, regular Bluefin to `projectbluefin/bluefin`,
Dakota to `projectbluefin/dakota`, and unknown variants to
`projectbluefin/common`. A GitHub issue URL uses its repository and issue
number directly.

Issue numbers must be positive integers. In a terminal, the exact comment is
shown and requires confirmation before posting; non-interactive use posts after
printing the preview. A signed-in GitHub CLI is required (`gh auth login`);
QR login is intentionally out of scope.

## bonedigger — what it does NOT do

The **full** issue lifecycle (slash commands, pipeline widget, label
transitions, stale sweep, auto-merge on lgtm) lives in
`projectbluefin/actions/.github/workflows/lifecycle.yml` and serves the factory
as a single reusable workflow.

bonedigger **does** still provide its own slim `lifecycle.yml` for bonedigger-specific features: agent donation fast-track and ujust-report intake. This is called separately from the actions lifecycle — see Integration status below.

See [`label-workflow.md`](./label-workflow.md) for the full lifecycle reference.

## kubestellar-bot - what it does

kubestellar-bot is the implementation agent layer. It:
- Monitors `status/queued` issues across all factory repos
- Dispatches agents to claim and implement fixes
- Manages the PR lifecycle from claim → ship
- Reports progress back to the hive dashboard

kubestellar-bot does NOT make design or security decisions. Those hit a human gate. See [`human-gates.md`](./human-gates.md).

## Integration status

The factory has two lifecycle workflows serving different purposes:

| Workflow | Location | Called by | Purpose |
|---|---|---|---|
| Full lifecycle | `projectbluefin/actions/.github/workflows/lifecycle.yml@main` | `common` via `lifecycle-caller.yml` | Pipeline widget, slash commands, label transitions, stale sweep, auto-merge |
| bonedigger slim | `projectbluefin/bonedigger/.github/workflows/lifecycle.yml@main` | `bluefin`, `bluefin-lts`, `dakota` via `bonedigger.yml` | Agent donation fast-track, ujust-report intake |

All internal `projectbluefin/` workflow refs use `@main` — **not SHA pins**. SHA pins on internal refs caused repeated `startup_failure` cascades when pins drifted; the pre-commit floating-tag guard already exempts `projectbluefin/*`. See [`ci-tooling.md`](./ci-tooling.md) § Internal refs.

If you find a `lifecycle-caller.yml` still pointing at `projectbluefin/common`, it is stale — delete it or update the target to `projectbluefin/actions`.

bonedigger’s `sync-templates.yml` continues to propagate issue templates to factory repos.

## Template sync

bonedigger's `sync-templates.yml` propagates issue templates from `bonedigger/templates/` to factory repos.

Requires `MERGERAPTOR_APP_ID` (var) and `MERGERAPTOR_PRIVATE_KEY` (secret) on
the bonedigger repo. Use the mergeraptor app token rather than a PAT.

## Lessons Learned

### Preserve drafts rather than transient reports

`/usr/libexec/bonedigger-report` stores a submission draft in the user's state
directory before any public upload. On a failed or declined submission, retain
that draft and print its exact `ujust report --resume …` command so reports are
not lost.

## Common Rationalizations

- “A full journal is more useful.” Targeted profiles are easier to review and
  less likely to expose unrelated data.
- “A missing label is harmless.” Do not make issue creation fail because an
  optional intake label is absent.
- “A failed upload can be retried from memory.” Preserve a draft and print the
  exact resume command instead.

## Red Flags

- Collecting diagnostics before the user selects an intent.
- Uploading a gist or creating an issue before preview and explicit consent.
- Applying both queue labels, using `machine-id`, or reviving generic OTel
  capture.
- Falling back to a browser issue form or a QR login flow.

## Verification

- [ ] Bug routing matches Bluefin, Bluefin LTS, Dakota, and the common fallback.
- [ ] A bug submits at most one supported queue label.
- [ ] Baseline and selected profile limits are enforced after redaction.
- [ ] Missing or unauthenticated `gh` leaves a resumable local draft.
- [ ] A confirmation accepts a positive number or GitHub issue URL without a
  persistent device identifier.

## Sources

GitHub CLI command options were verified against Context7 source
`/websites/cli_github_manual`: `gh issue create` supports `--repo`, `--title`,
`--body-file`, and `--label`; `gh gist create --public` publishes selected files.
