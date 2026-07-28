# CONTRIBUTING

Thanks for helping out!

Check the [Contributing Guide](https://docs.projectbluefin.io/contributing) for contribution information.

This repository is the **shared OCI layer** consumed by all Bluefin image variants. Changes here propagate to `bluefin`, `bluefin-lts`, and `dakota`. Stay surgical — see the scope warning in [`AGENTS.md`](./AGENTS.md). Make sure you also check [the architecture diagram](https://docs.projectbluefin.io/contributing#understanding-bluefins-architecture).

- For Bluefin-specific image changes: [projectbluefin/bluefin](https://github.com/projectbluefin/bluefin)
- For LTS image changes: [projectbluefin/bluefin-lts](https://github.com/projectbluefin/bluefin-lts)
- For dakota changes: [projectbluefin/dakota](https://github.com/projectbluefin/dakota)
- For shared system config (Aurora-compatible files): edit `system_files/shared/` directly in this repo

## How this repo uses agents

This repo is **human-first for issues.** Humans file issues, triage them, and decide what gets built.
Automated agents (clanker, kubestellar-bot, etc.) implement approved work — they do not self-direct
triage or close issues without human approval.

### Queueing work for clanker

Add the `clanker-queue` label to any triaged issue you want an autonomous agent to implement.

```
You (human): add clanker-queue  →  clanker picks it up and opens a PR
```

Requirements before adding `clanker-queue`:
1. The issue must have at least one `kind/` label and one `area/` label set.
2. The issue description must be clear enough for an agent to implement without follow-up questions.
   Vague issues stay in `clanker-queue` indefinitely — no agent will guess at the spec.

To add the label via CLI:
```bash
gh issue edit <number> --repo projectbluefin/common --add-label clanker-queue
```

### Where other automation lives

Broader factory automation (E2E testing, image promotion gating, regression detection) is
handled in [projectbluefin/testing](https://github.com/projectbluefin/testing), not here.
If you want to improve automated test coverage or CI pipelines, that's the right place.

### Full label and lifecycle docs

See [`docs/skills/label-workflow.md`](docs/skills/label-workflow.md) for the complete label
taxonomy, slash commands (`/approve`, `/claim`, `/unclaim`), and the agent–human handoff model.

## CI

PRs require only `validate-just` and `build` to pass — no expensive VM boots. Full layer validation (`common` behave suite via [`projectbluefin/testsuite`](https://github.com/projectbluefin/testsuite)) runs automatically on every merge to main.
