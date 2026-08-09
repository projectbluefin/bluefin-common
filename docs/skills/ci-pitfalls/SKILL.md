---
name: ci-pitfalls
version: "1.1"
last_updated: "2026-08-08"
id: ci-pitfalls
one_line_purpose: Diagnose CI gotchas and silent workflow failures across repos.
entry_point: docs/skills/ci-pitfalls/SKILL.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [ci, workflows, github-actions, pitfalls]
description: >-
  Incident log of CI gotchas across projectbluefin repos. Use when debugging
  silent CI failures, startup_failure, or workflow skip behavior.
metadata:
  type: reference
  context7-sources:
    - /actions/checkout
    - /actions/create-github-app-token
    - /github/codeql-action
    - /redhat-actions/buildah-build
    - /containers/skopeo
    - /renovatebot/renovate
---

# CI Pitfalls — incident log

> Split from [`ci-tooling.md`](../ci-tooling/SKILL.md) on 2026-06-24. This file holds the incident-log / gotcha entries — patterns that have caused silent CI failures or `startup_failure` across factory repos. [`ci-tooling.md`](../ci-tooling/SKILL.md) retains policy and config; [`shell-scripts`](../shell-scripts/SKILL.md) retains shell authoring and testability.

<!-- TODO(context7): verify all GitHub Actions behavior claims (workflow_run name matching, merge_group ref handling, create-github-app-token scoping, caller permissions inheritance) against upstream docs. These were documented from live incident debugging, not from Context7 lookups. -->

## When to Use

- Debugging a CI failure that silently skips a gate or shows `startup_failure` with no error output
- A merge queue PR is stuck or a post-merge e2e gate never fires
- A Renovate PR passes all checks but never merges
- A `build.yml` push step fails with `image not known` or `UNAUTHORIZED`
- A ruleset blocks the merge queue with no matching check name

## When NOT to Use

- Policy and configuration (SHA pinning, floating-tag guard, pre-commit hooks) → [`ci-tooling.md`](../ci-tooling/SKILL.md)
- Shell script authoring and testability patterns → [`shell-scripts`](../shell-scripts/SKILL.md)

---

## Red Flags

- A PR targets `testing` but the branch was created from `main`
- A reusable workflow job shows `startup_failure` with no error output (check caller `permissions:`)
- A `workflow_run`-triggered gate silently never fires (name mismatch)
- A Renovate PR passes all checks but never merges (check `autoMergeRequest`)
- A merge queue PR is stuck with no matching check name (ruleset check name drift)
- `create-github-app-token` fails with `Invalid keyData` (owner + repositories scoping)

---

## Verification

- [ ] For `.github/workflows/` changes, run `pre-commit run --all-files` and `actionlint .github/workflows/*.yml`
- [ ] If a pitfall describes GitHub Actions behavior (workflow_run, merge_group, permissions inheritance, app token), verify it against Context7 and record the library ID in frontmatter
- [ ] If a pitfall describes Renovate behavior (platformAutomerge, automerge API), verify it against Context7
- [ ] If a pitfall describes buildah/podman/cosign behavior, verify it against Context7
- [ ] Confirm the "Fix already in place" steps still exist in the workflow files they reference — do not document a fix that has been removed

## References

| File | Contents |
|---|---|
| [pr-and-branch.md](references/pr-and-branch.md) | Branch-from-target rule, bulk SHA bump regex trap, actions PR consumer validation evidence format |
| [permissions-and-triggers.md](references/permissions-and-triggers.md) | Caller-level permissions starvation, workflow_run name matching, merge_group + upload-sarif ref failure |
| [build-and-push.md](references/build-and-push.md) | Rootless buildah vs root podman storage, GHCR login required before cosign signing |
| [automerge-and-rulesets.md](references/automerge-and-rulesets.md) | Renovate automerge mechanics, renovate-automerge.yml merge queue, ruleset required status check names, create-github-app-token cross-repo scoping |
