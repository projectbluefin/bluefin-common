# Cache keys and junction hygiene

Reference for [`../SKILL.md`](../SKILL.md). Sources: BuildStream docs
(`/apache/buildstream`) sections `arch_cachekeys.md`, `format_public.md`,
`junctions/junction-elements.md`; dakota `docs/skills/bst-overrides.md`,
`patch-junctions.md`, `oci-layers.md`; fsdk-containers
`docs/skills/bump-fsdk-version.md`.

## The cache-key model

BuildStream has two cache-key types (`arch_cachekeys.md`):

- **Strong key** — captures everything that influences build output: the
  element's own config, variables, environment, source refs, and the strong
  keys of all build *and* runtime dependencies, recursively.
- **Weak key** — includes only the *names* of build dependencies. It changes
  when the element itself changes, not when a dependency is updated.

Strict builds (the default build plan) use strong keys. Non-strict builds
reuse any artifact matching the weak key — faster, but reverse dependencies
are not automatically rebuilt.

### Consequence: invalidation cones

| Change | What is invalidated |
|---|---|
| Junction ref bump | Every element the junction provides, recursively downstream (widest cone) |
| `patch_queue` on a junction | Same as a ref change: the junction's source hash changes, so every imported element's key changes |
| `project.conf` options/variables | Project-wide |
| Leaf element ref bump | That element plus its reverse dependencies |
| Workflow/Justfile/docs edits | Nothing — no cache impact |

Merge-order rule that follows from this: leaf bumps first, junction bumps
last, one at a time, each verified green before the next.

### Consequence: weak-key staleness

Symptom verified in dakota: a new package is added to a `stack` element, the
build succeeds, but the package is missing from the composed image — the
stack's weak key did not change, so the downstream `compose` was served from
cache. If the graph is right but the output is stale, suspect cache
invalidation before debugging the element.

### Consequence: failed builds are cached

A failed build is cached as a failed artifact; retries exit immediately.
Delete it before rebuilding: `bst artifact delete <element>`.

## Junction hygiene (upstream-first policy)

Both factory BST repos junction `freedesktop-sdk` (dakota also junctions
`gnome-build-meta`) and rely on upstream public artifact caches. Because a
junction's source hash feeds every imported element's key:

1. **Check upstream first.** If the fix is in a newer upstream ref, bump the
   junction ref instead of patching.
2. **Never edit junction `.bst` content directly** and keep junctions clean
   of downstream `patch_queue` sources — a local patch silently forces
   from-scratch compiles of the entire imported graph by making upstream
   cache artifacts unreachable. (dakota measured this: removing the GBM
   patch queue restored 1053 of 1090 cached elements.)
3. **Local overrides are last-resort debt.** Every override or temporary
   patch carries an exit condition (`# Exit condition: Drop after fdsdk
   ships X`) and, where upstreamable, an `Upstream-Status: Submitted <URL>`
   header. Re-audit overrides at every junction bump.
4. **Where cache reuse matters, keep junction files byte-aligned with the
   upstream project that publishes the cache** — even semantically equal
   diffs change keys.

Patch ordering note: when a repo does carry a patch queue, patches apply in
alphabetical filename order; numbering gaps are deliberate insertion room.

## Remote execution evidence

Both repos dispatch build actions to the shared BuildBarn grid. The log line
`Waiting for the remote build to complete` per element is the evidence that
remote execution is active; local sandbox staging messages for build actions
mean RE is not engaged. RE and artifact caching are separate mechanisms —
per-repo endpoints and auth live in the repo's own skills.
