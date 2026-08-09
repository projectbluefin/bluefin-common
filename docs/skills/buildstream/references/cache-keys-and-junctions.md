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
| `patch_queue` diverging from the parent project's queue | Same width as a ref change: keys no longer match the parent's published cache. A queue matching the parent's byte-for-byte is how cache reuse is *preserved* — see drift control below |
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

## Junction hygiene: drift control, not "never patch"

Both factory BST repos junction `freedesktop-sdk` (via a `gnome-build-meta`
junction) and rely on upstream public artifact caches. A junction's sources —
**including any `patch_queue`** — feed its source hash, which feeds every
imported element's cache key. The patch queue therefore determines *which*
upstream artifact cache you can reuse:

- A patch that **diverges** from the parent project's own queue is
  cache-destroying. dakota measured this: a downstream-only patch on the
  `gnome-build-meta` junction silently forced from-scratch compiles of the
  imported graph (removing it restored 1053 of 1090 cached elements). This is
  the thing to prohibit — not patches in general.
- A patch queue that **replicates** the parent project's queue byte-for-byte
  at your pinned ref is cache-*aligning* — mandatory when the parent carries
  one, because matching it is what makes your keys line up with the parent's
  published cache. Both repos do this today: dakota carries 7 patches in
  `patches/freedesktop-sdk/` (byte-identity with GBM's queue at the pinned
  ref is documented in `dakota/docs/skills/bst-overrides.md`), and
  fsdk-containers carries 0001+0002, with `elements/gnome-build-meta.bst`
  noting its fdsdk junction "has to match what gnome-build-meta is using".

The enforceable rule is **drift control against the parent project's queue at
the pinned ref**: dakota implements this as `just patch-drift-check` (diffs
GBM's queue at the pinned commit against the local one) run in CI;
fsdk-containers re-checks that its two CAS-config patches still apply at
every FSDK bump. The per-repo parameter is *which* upstream project's queue
you must match — currently `gnome-build-meta` at the repo's pinned ref in
both repos.

Supporting rules:

1. **Check upstream first.** If the fix is in a newer upstream ref, bump the
   junction ref instead of patching.
2. **Never edit junction `.bst` content directly** — changes go through the
   junction element's sources/overrides so the cache impact is explicit.
3. **Local overrides are last-resort debt.** Every override or temporary
   patch carries an exit condition (`# Exit condition: Drop after fdsdk
   ships X`) and, where upstreamable, an `Upstream-Status: Submitted <URL>`
   header. Re-audit overrides at every junction bump.
4. **Byte-alignment is the bar where cache reuse matters** — even
   semantically equal diffs to the parent's junction file or patch queue
   change keys.

Patch ordering note: patches within a queue apply in alphabetical filename
order; numbering gaps are deliberate insertion room.

## Remote execution evidence

Both repos dispatch build actions to the shared BuildBarn grid. The log line
`Waiting for the remote build to complete` per element is the evidence that
remote execution is active; local sandbox staging messages for build actions
mean RE is not engaged. RE and artifact caching are separate mechanisms —
per-repo endpoints and auth live in the repo's own skills.
