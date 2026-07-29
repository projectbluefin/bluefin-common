# Proposal: a shared skill-catalog standard across the factory

**Status: proposal, not adopted.** Nothing in this document is implemented.
It requires a human Design-gate decision (see
[`docs/skills/human-gates.md`](../skills/human-gates.md)) before any repo —
including `common` — builds or changes anything described here. No sibling
repo (`actions`, `bluefin-lts`, `testsuite`, etc.) has been touched to
produce this proposal.

## Why this exists

A 2026-07-29 audit of `common`'s `docs/skills/` system was originally run
against a **phantom local state**: an unpushed, diverged local `main` branch
carried experimental commits (`0e511f5`, `d5c90a7`) adding a machine-readable
`index.json` + `index.schema.json` + `generate_skill_index.py` generator with
extra front-matter fields (`id`, `category`, `mcp_compliance_level`,
`optimization_status`, `dependencies`, `status`, `entry_point`,
`one_line_purpose`). **None of that exists on `origin/main`.** `common`'s
real, current front-matter contract is only `name`, `version`,
`last_updated`, `tags`, `description`, `metadata.type` — see
[`write-a-skill.md`](../skills/write-a-skill.md).

While correcting that, a survey of every sibling factory repo on disk
(`bluefin`, `bluefin-lts`, `dakota`, `knuckle`, `testsuite`, `actions`,
`bonedigger`, `clankers`, `hive`) found real, useful divergence worth
proposing a standard for — summarized below.

## Current state (verified 2026-07-29)

| Repo | Router | Skill shape | Machine catalog | Validator |
|---|---|---|---|---|
| `common` | `docs/SKILL.md` | flat `docs/skills/*.md` (+ one migrated `docs/skills/lab-testing/SKILL.md`) | none | `check-skill-frontmatter.sh`, `check-skill-index.sh` |
| `bluefin` | `docs/SKILL.md` | flat | none | none found |
| `bluefin-lts` | `docs/skills/INDEX.md` | per-skill directories, `name`+`description` only front matter | none (hand-maintained `INDEX.md`) | `scripts/check-skill-docs.py` — link-integrity + directory/name consistency + 500-line hard cap |
| `dakota` | `docs/SKILL.md` + `docs/skills/INDEX.md` | flat (~28 files) | none (the only `index.json` present is an unrelated OCI build artifact under `.build-out/`) | none found |
| `knuckle` | `docs/SKILL.md` | flat, smallest set | none | none found |
| `testsuite` | `docs/skills/index.md` | category-named subfolders (`ci-ops/`, `meta/`, `test-authoring/`, plus an ad hoc `flatpak-screenshots/`) | **design-only**: `docs/superpowers/specs/2026-07-28-skill-discovery-index-design.md` proposes a schema that mirrors `common`'s phantom-local design almost field-for-field, unimplemented | none yet |
| `actions` | `docs/SKILL.md` | flat + two reference subfolders | none (has an unrelated `docs/schemas/release-state.schema.json`) | none |
| `bonedigger` | `agents.md` (no `SKILL.md`) | flat | none | none |
| `clankers` | none | none | none | none |
| `hive` | none | none | none | none |

## Confirmed, independent-of-this-proposal bug

`projectbluefin/actions`' `.github/workflows/skill-drift-check.yml` — the
reusable workflow every consumer repo's `skill-drift.yml` calls — is
currently a **no-op stub** (real logic removed in `actions@001ae97`, replaced
with a compatibility stub in `actions@a7c230c`). It always exits 0 without
inspecting any changed paths. Every repo above that has a `skill-drift.yml`
(bluefin, bluefin-lts, dakota, knuckle, testsuite) is getting a silent,
always-green result. `common` does not run it at all (see
[`ci-tooling.md`](../skills/ci-tooling.md#skill-drift-detection)). This is
already corrected in `common`'s own docs
([`skill-drift.md`](../skills/skill-drift.md),
[`factory-onboarding.md`](../skills/factory-onboarding.md)) as part of the
same PR that added this proposal — it is not itself a proposal, it is a
verified fact.

## Proposed direction (needs human sign-off before any repo acts on it)

1. **Do not let each repo reinvent a JSON catalog independently.** `common`
   already did this once as unreviewed local-only work; `testsuite` has an
   unimplemented design that mirrors it closely. If a machine-readable
   catalog is wanted, design it once, get it reviewed, and land it as a single
   schema — not N similar-but-incompatible ones.
2. **Host the canonical JSON Schema in `projectbluefin/actions`.** `actions`
   already hosts reusable workflows every repo consumes (including the
   skill-drift check); it's the natural place for one `skill-index.schema.json`
   referenced by every repo's generator, instead of drifting per-repo copies.
3. **Keep per-repo front matter minimal.** Only `bluefin-lts` and `knuckle`
   currently ship minimal front matter (`name` + `description`, or `common`'s
   slightly larger `name/version/last_updated/tags/description/metadata.type`)
   and neither needs a catalog to function. Any shared schema should make
   catalog-only fields (equivalent to the old `category`/`mcp_compliance_level`/
   `optimization_status`/`dependencies`) **optional and additive**, not
   mandatory front matter every repo must carry whether or not it builds a
   catalog.
4. **Rebuild or remove `skill-drift-check.yml`.** Either restore real
   drift-detection logic in `actions`, or have every consumer repo delete its
   now-decorative `skill-drift.yml` per the stub's own comment
   (`# Consumer repos should delete their skill-drift.yml on next maintenance
   pass.`). Leaving it as a silently-passing no-op is worse than having no
   check at all, because it looks like enforcement.
5. **Genericize `bluefin-lts`'s `check-skill-docs.py`.** It's the only real
   link-integrity + directory/name-consistency validator anywhere in the
   factory. `common`'s own `check-skill-frontmatter.sh` /
   `check-skill-index.sh` only check front-matter shape and router-table
   presence, not that every relative link inside a skill body resolves.
   Consider porting `check-skill-docs.py`'s link-checking logic into a shared
   `actions` script/action all repos can call.
6. **Bootstrap `clankers` and `hive` with the minimal flat pattern**
   (`AGENTS.md` → `docs/SKILL.md` → `docs/skills/*.md`), not a per-skill-directory
   or JSON-catalog pattern — they have zero skill-system state today, so
   starting with `bluefin`/`knuckle`'s simplest shape is proportionate; a
   catalog can be added later if/when this proposal is adopted.
7. **If `testsuite` wants to proceed with its design doc**, coordinate first
   rather than building independently — their spec already assumes the same
   field set this proposal recommends keeping optional/catalog-only, so a
   shared schema in `actions` would let both repos consume the same contract.

## Explicitly out of scope for this proposal

- No changes to `actions`, `bluefin`, `bluefin-lts`, `dakota`, `knuckle`,
  `testsuite`, `bonedigger`, `clankers`, or `hive`. Those require their own
  PRs, reviewed by their own maintainers, in their own repos.
- No revival of the phantom local `index.json`/`index.schema.json`/
  `generate_skill_index.py` system in `common`. If `common` later decides to
  build a catalog, it should follow whatever schema comes out of the
  cross-repo decision above, not resurrect the unreviewed local design.

## Verification

- Dead workflow: `git -C <actions checkout> show
  a7c230c:.github/workflows/skill-drift-check.yml` — confirms the no-op stub
  body and the "restore ... as a no-op stub for consumer compat" commit
  message.
- Phantom local commits: `git -C <common checkout> log --oneline
  origin/main..main` — lists the 3 unpushed commits not present on any
  remote branch (flagged for the repository maintainer to decide whether to
  drop or resurrect; not acted on by this proposal).
- `testsuite` design doc: `docs/superpowers/specs/2026-07-28-skill-discovery-index-design.md`
  in the `testsuite` checkout.
- `bluefin-lts` validator: `scripts/check-skill-docs.py` in the `bluefin-lts`
  checkout.
