# Pre-Commit Conventions

Part of [ci-tooling](../SKILL.md) — Pre-commit auto-fix loop, AI commit attribution, release-state.yaml schema validation, Skill drift detection, and Docs hygiene hooks.

---

## pre-commit auto-fix hooks modify files and abort the commit

When a pre-commit hook fixes a file in place, treat that run as a **failed gate that also produced a patch**. The hook output typically ends with `Files were modified by this hook`, the commit does not proceed, and you must review + re-stage the modified files before retrying.

Typical loop:

```bash
pre-commit run --all-files
git diff -- docs/skills/ci-tooling/SKILL.md   # or inspect all modified files
git add <fixed-files>
pre-commit run --all-files
```

Do **not** assume the original staged snapshot is still current after an auto-fix hook. Re-stage the files the hook touched, or the next commit attempt will either fail again or commit an older index state than the working tree.

---

## AI commit attribution (convention, not CI-gated)

AI-authored commits should carry both trailers as a convention:

```
Assisted-by: Claude Sonnet 4.6 via pi
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

The `validate.yml` attribution check was removed — it is **not** a CI gate. A missing or single trailer does not block your PR. Including both trailers is the expected convention but will never cause `exit 1`.

Note: `pi`-authored commits use `Assisted-by: <Model> via pi`. The `Co-authored-by: Copilot` trailer is optional but conventional.

---

## release-state.yaml schema validation

`.github/release-state.yaml` should be validated with the `check-jsonschema` pre-commit hook against the shared schema in `projectbluefin/actions`.

### Pin both the hook and the schema source

Use an immutable hook revision **and** an immutable raw schema URL pinned to the `actions` commit that introduced the schema:

```yaml
- repo: https://github.com/python-jsonschema/check-jsonschema
  rev: <commit-sha> # <version>
  hooks:
    - id: check-jsonschema
      files: ^\.github/release-state\.yaml$
      args:
        - --schemafile
        - https://raw.githubusercontent.com/projectbluefin/actions/<commit-sha>/docs/schemas/release-state.schema.json
```

Pinning the raw URL to a commit avoids silent schema drift on the next pre-commit run if `actions/main` changes. The hook is file-scoped, so `pre-commit run --all-files` is a no-op in repos that do not currently carry `.github/release-state.yaml`.

---

## Skill drift detection

**Retired across the factory. Do not re-add it in any repo.**

`skill-drift.yml` never enforced anything. It called the reusable workflow
`projectbluefin/actions/.github/workflows/skill-drift-check.yml`, whose real
logic was removed in `actions@001ae97` and replaced with a compatibility stub
in `actions@a7c230c`. The stub echoed `"Skill drift check removed. Delete
skill-drift.yml from consumer repo."` and exited successfully without
inspecting a single changed path.

Five repos (bluefin, bluefin-lts, dakota, knuckle, testsuite) called that stub
on every PR and received a silent green result regardless of what changed.
`common` never wired it up. The callers and the stub have since been deleted.

Skill-update discipline is enforced at developer time by `pre-commit` and by
the self-repair loop in [`skill-improvement.md`](../../skill-improvement.md) — not
by a CI exit code. Per [`agentic-model.md`](../../../factory/agentic-model.md), the
aggregate `pre-commit` step is the only place a process convention may fail a
build; bespoke per-convention CI jobs are banned.

Retirement record: [`skill-drift.md`](../../skill-drift.md)

---

## Docs hygiene pre-commit checks

The repo-level `.pre-commit-config.yaml` includes local hooks that protect the
agent docs structure:

| Hook | Script | What it checks |
|---|---|---|
| `Validate skill front-matter` | `scripts/check-skill-frontmatter.sh` | Every `docs/skills/*.md` has required front-matter keys (`name`, `version`, `last_updated`, `tags`, `description`, `metadata.type`) and description ≤256 chars. |
| `Validate docs/SKILL.md skill index` | `scripts/check-skill-index.sh` | `docs/SKILL.md` links to every skill file in `docs/skills/`. |
| `Validate internal markdown links` | `scripts/check-doc-links.sh` | Every relative `.md` link in `docs/` resolves to an existing file. |

These are **hygiene gates**, not blocking CI workflow gates, consistent with the
factory rule that process conventions are agent-enforced. The front-matter size
budget is soft at 200 lines and hard at 500 lines; oversized legacy skills are a
burn-down list — migrate them to the per-skill directory layout on sight
(`docs/skills/<name>/SKILL.md` + `references/`), in the same change that touches
them. See `write-a-skill.md`.
