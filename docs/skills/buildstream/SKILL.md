---
name: buildstream
version: "1.0"
last_updated: "2026-08-09"
id: buildstream
one_line_purpose: Apply the BuildStream 2 patterns shared by every factory BST repo.
entry_point: docs/skills/buildstream/SKILL.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: [context7]
tags: [buildstream, bst, elements, junctions, caching]
description: >-
  Cross-repo BuildStream 2 conventions for the factory's BST repos (dakota,
  fsdk-containers): element kinds, dependency types, cache keys, junction
  hygiene, source tracking. Use when authoring .bst elements, debugging BST
  builds, or bumping junction refs.
metadata:
  type: reference
  context7-sources:
    - /apache/buildstream
---

# BuildStream (BST) — factory-wide patterns

## When to Use

Use when authoring or editing `.bst` elements, debugging BST graph/build/cache
failures, tracking sources or bumping junction refs, or deciding whether a BST
pattern belongs in `common` or stays repo-local.

## When Not to Use

- Repo-specific recipes: dakota's OS packaging (`dakota/docs/skills/add-package.md`,
  `packaging-*.md`, `oci-layers.md`) and fsdk-containers' distroless recipe
  (`fsdk-containers/docs/skills/slim-an-image.md`, `verify-distroless/`) live in
  those repos and are deliberately NOT promoted here.
- Containerfile-based repos (common, bluefin, bluefin-lts) — see
  [`containerfile`](../containerfile/SKILL.md).
- Asserting BST behavior from memory — Context7 lookup first
  (`/apache/buildstream`), per [`context7.md`](../context7.md).

## Scope rule: what is factory-general

This skill records only what is **true in every factory BST repo** (today:
`dakota` and `fsdk-containers`). Both are BuildStream 2 projects that junction
freedesktop-sdk and pull from shared upstream artifact caches.

The following are **per-repo product decisions, not factory rules** — never
copy them across repos:

| Decision | dakota | fsdk-containers |
|---|---|---|
| What is composed | Bootable bootc OS; desktop platform content in scope | `components/*` only; `platform.bst` banned (AGENTS.md hard rule) |
| Micro-arch | Opt-in `x86_64_v3` option (`project.conf`) | `x86_64_v3` banned — broad-compatibility baseline |
| Output contract | Bootable OS image (systemd, shell, dconf, ldconfig-for-bootc) | Distroless OCI: no shell, SLIM recipe, `just verify` gates |

When a pattern is general but its parameters differ, this skill names the
pattern and points at the per-repo parameter source (`project.conf` options,
repo `AGENTS.md`).

## Core patterns

### 1. Graph-first workflow

`bst show` before `bst build` — graph/YAML errors surface in seconds; a build
is the slowest feedback loop. Classify a failure (graph / fetch / compile /
install / composition) before opening a `bst shell --build` sandbox. Inspect
`bst artifact log` and `bst artifact list-contents` before guessing. Failed
builds are cached as failed artifacts — `bst artifact delete <element>` before
retrying.

### 2. Element kinds are load-bearing

`stack` aggregates dependencies and produces **no filesystem output**;
`compose` is the filesystem-producing filter step (build-deps only);
`script` runs assembly commands; `junction` is a subproject boundary. A layer
element written as `stack` builds successfully and ships an empty layer —
the most common composition bug. (Source: BuildStream docs →
`handling-files/composition.md`.) Available plugin kinds are per-repo (dakota's
graph registers `meson`/`cmake`/etc.; fsdk-containers hand-writes
`kind: manual` only) — check the repo's `project.conf` before choosing a kind.

### 3. Dependency types are about *when*, not just *what*

`build-depends` is staged only for this element's own build; `runtime-depends`
is NOT staged for this element's build, only for its consumers; plain
`depends` is both. Listing a build-time tool under `runtime-depends` fails
silently until a confusing downstream error (e.g. `ModuleNotFoundError` deep
in an install script).

### 4. Cache keys and junction blast radius

An element's strong cache key covers its own config plus all dependency keys,
recursively. A junction ref bump therefore invalidates every element the
junction provides, and any `patch_queue` on a junction destroys artifact
reuse against upstream public caches. Non-strict (weak-key) builds can serve
stale artifacts — symptom: a package builds but is missing from the composed
image. (Source: BuildStream docs → `arch_cachekeys.md`.) Details and policy:
[`references/cache-keys-and-junctions.md`](references/cache-keys-and-junctions.md).

### 5. Junction hygiene: upstream-first

Never edit junction `.bst` content directly; keep junctions clean of
downstream patch queues; prefer an upstream fix or ref bump over a local
override; every override/patch carries a written exit condition. Local
override debt is re-audited at every junction bump.

### 6. Source and ref discipline

`bst source track` writes `ref:` fields — never hand-write a `git_repo` ref.
A version selector and its cryptographic `ref` update atomically (no
Renovate-style version-only bumps). Derived vendor blocks (`cargo2`,
`go_module`) are NOT regenerated by `source track` — regenerate them after
every ref bump. Variables do not expand in `sources[].url:` — use URL
aliases. Keep install commands hermetic: no `$(date)`, `$(curl ...)`, or
network access at build time.

### 7. Authoring gotchas verified in both repos

Bare/minimal sandboxes may have **no shell** (`Staged artifacts do not
provide command 'sh'`) and no `find`; remote-execution sandboxes may lack
`/dev/stdin` — write inline files with `install -Dm644 /dev/null` +
`cat > target <<'EOF'`. Option names are alphanumeric + underscore only
(BuildStream docs → `format_project.md`); option names/values are per-repo —
read `project.conf` before writing `(?):` conditionals. `overlap-whitelist`
only *permits* an overlap; staging order (and `integration-commands`, which
run after all staging) decides which file wins.

Full authoring reference:
[`references/element-authoring.md`](references/element-authoring.md).

## Remote execution

Both BST repos run builds on the shared ghost-cluster BuildBarn grid via
per-repo wrappers; success evidence in the log is `Waiting for the remote
build to complete` per built element. Endpoints, auth, and opt-outs are
per-repo: `dakota/docs/skills/debugging.md` (RE-first policy),
`fsdk-containers/docs/skills/remote-execution.md`. Do not copy endpoint
configuration between repos.

## Red Flags

- Copying a composition baseline (`platform.bst` vs `components/*`), arch
  option, or output recipe from one BST repo into the other.
- `kind: stack` where filesystem output is expected.
- A `patch_queue` or local patch on a junction without an exit condition and
  an upstream link — it invalidates every downstream cache key.
- Hand-written `git_repo` refs, or a version bump without its `ref` bump.
- Building before `bst show` validates; sandboxing before reading the log.
- Asserting BST flags/config keys without a Context7 `/apache/buildstream`
  lookup in the session.

## Verification

- [ ] `bst show` on the top-level target resolves before any build.
- [ ] Element kind matches the expected output (filesystem ⇒ `compose`).
- [ ] Junction changes state their cache blast radius and exit condition.
- [ ] Derived vendor blocks regenerated after any `source track`.
- [ ] Repo `AGENTS.md` hard rules checked for per-repo parameters.

## References

| File | Description |
|---|---|
| [`references/cache-keys-and-junctions.md`](references/cache-keys-and-junctions.md) | Strong/weak cache keys, invalidation cones, junction hygiene and upstream-first override policy. |
| [`references/element-authoring.md`](references/element-authoring.md) | Element/source kinds, dependency types, variables, conditionals, sandbox constraints, overlap rules. |
