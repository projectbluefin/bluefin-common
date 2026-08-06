# bluefin-common PR

## What does this change?

<!-- Required: one sentence -->

## Why?

<!-- Link the issue this closes: "Closes #NNN" -->
Closes #

## PR pipeline

```
opened ──▶ 4-review ──▶ approved ──▶ merged
```

> A maintainer reviews and approves; merge goes through the merge queue.
> Select `blocked` or `hold` to pause the work.

## Checklist

- [ ] PR title follows Conventional Commits (`fix:`, `feat:`, `docs:`, `ci:`, `refactor:`, etc.)
- [ ] `just check` passes
- [ ] `pre-commit run --all-files` passes
- [ ] Skill doc updated if the change affects agent-facing conventions or behavior (see `docs/skills/skill-improvement.md`)
- [ ] `AGENTS.md` / `docs/SKILL.md` / `docs/skills/` links remain valid
- [ ] CI is green after push: `gh run list --repo projectbluefin/common --limit 5`

## AI attribution

If this PR includes AI-authored commits, include both trailers:
```
Assisted-by: <Model> via GitHub Copilot
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```
