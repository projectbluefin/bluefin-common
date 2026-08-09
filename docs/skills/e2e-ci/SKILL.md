---
name: e2e-ci
version: "1.1"
last_updated: "2026-08-08"
id: e2e-ci
one_line_purpose: Debug pre/post-merge E2E CI for common.
entry_point: docs/skills/e2e-ci/SKILL.md
category: test-authoring
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [e2e, testing, ci]
description: >-
  Pre/post-merge E2E CI for common. Use when debugging E2E failures,
  understanding the PR gate flow, or diagnosing masked brew-setup issues.
metadata:
  type: reference
---

# E2E CI

## When to Use

Use when debugging E2E failures, understanding the PR gate flow, diagnosing
masked `brew-setup` issues, or wiring E2E as a gate in a promotion pipeline.

## When Not to Use

Do not use this skill for lab/KubeVirt testing (see
[`../lab-testing/SKILL.md`](../lab-testing/SKILL.md)), or for generic GitHub
Actions authoring unrelated to the `common` test workflows.

## Post-merge E2E

**File:** `.github/workflows/e2e.yml`

- Runs after merges to `main`
- Calls the local `.github/workflows/run-testsuite.yml` wrapper, which centralizes the pinned `projectbluefin/testsuite` SHA
- Validates the common layer against three downstream images:
  - `ghcr.io/projectbluefin/bluefin:latest`
  - `ghcr.io/projectbluefin/bluefin:lts`
  - `ghcr.io/projectbluefin/dakota:testing`
- Uses SSH-mode tests from the runner, so the common suite does not require a full GNOME session

## Pre-merge gate

**File:** `.github/workflows/pr-e2e.yml`

- Runs on PRs to `main` and on `merge_group`
- Builds the PR's `common` layer candidate first
- Composes a downstream test image from `ghcr.io/projectbluefin/bluefin:stable` by overlaying `/system_files/shared` and `/system_files/bluefin`
- Recompiles GSettings schemas in the composed image
- Pushes the composed image to GHCR and runs the local testsuite wrapper with `suites: common`

This is the pre-merge gate for common-layer changes, so regressions can fail before merge instead of waiting for post-merge E2E.
In branch protection today it is still an advisory/non-required signal; `build.yml` remains the required merge check.

Use a stable downstream base for this PR-time compose gate. The moving `:testing`
stream belongs in `promotion-candidate-e2e.yml`; using it here makes unrelated
downstream churn (for example missing CLI tools in the current testing image)
fail `common` PRs that only change the shared layer.

## Promotion-candidate feedback loop

**File:** `.github/workflows/promotion-candidate-e2e.yml`

- Runs weekly on Tuesdays before the downstream Bluefin promotion workflows
- Tests the exact candidate tags used for promotion from common's side:
  - `ghcr.io/projectbluefin/bluefin:testing`
  - `ghcr.io/projectbluefin/bluefin:lts-testing`
- Runs `smoke,common` to add a boot/basic-usage signal on top of the shared-layer checks
- Uses the same local testsuite wrapper as PR/post-merge workflows, so the testsuite SHA stays aligned

This is **not** a full installer gate. It is the smallest safe repo-local improvement common can make without editing downstream image repos or installer pipelines.

## Known CI caveats and quarantines

- `brew-setup.service` is masked in CI, so Homebrew-installed CLI tools are not present unless explicitly provisioned during the job
- `testsuite#210` tracks the `bash -lc` PATH mismatch affecting `zsh`/`fish` checks in the CI user environment
- GNOME Software scenarios are intentionally `@quarantine` after `testsuite#258`; they should not be treated as active software-store coverage
- Bazaar coverage is currently a `@pending` placeholder tied to the same gap
- `ujust report --confirm` scenario (`system_health.feature`) is `@quarantine` — the `--confirm` mode is not implemented in any current image variant; the step skip-detection used the wrong error string. See testsuite PR #259. Re-enable when `report --confirm` lands in the image Justfile.

## Testsuite SHA pin

`common/.github/workflows/run-testsuite.yml` pins the testsuite SHA for all repo-local callers. When the pin lags behind `main`, quarantined scenarios may run and cause spurious failures. `common` has Renovate configured (`renovate.json`) but the testsuite SHA pin may need manual updates when testsuite fixes land — check `chore(deps): update` Renovate PRs.

## Red Flags

- Using `:testing` as the compose base for `pr-e2e.yml` (causes false failures from unrelated downstream churn).
- A `workflow_run` trigger fix pushed only to `testing` (default-branch constraint means it has no effect until it reaches `main`).
- The `promote-to-testing` job running on branches other than `main` (double-promotion risk).
- An unanchored `--certificate-identity-regexp` wildcard in cosign verify.

## Verification

- [ ] `pr-e2e.yml` uses a stable (not `:testing`) base image.
- [ ] `run-testsuite.yml` SHA pin matches the testsuite commit being relied on.
- [ ] Promotion `promote-to-testing` job is gated on `head_branch == 'main'`.
- [ ] cosign identity regexp is anchored with `^...$`.

## References

| File | Description |
|---|---|
| [`references/promotion-patterns.md`](references/promotion-patterns.md) | `promote-to-testing` job pattern, TOCTOU guard, cosign verify anchoring, and cosign install on GHA runners. |
| [`references/never-stall-design.md`](references/never-stall-design.md) | Promotion gate never-stall design: E2E on testing branch, feedback trigger, jq selector, and bluefin bootstrap. |
