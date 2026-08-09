# Element authoring reference

Reference for [`../SKILL.md`](../SKILL.md). Sources: BuildStream docs
(`/apache/buildstream`) sections `format_project.md`, `format_public.md`,
`handling-files/composition.md`; dakota `docs/skills/buildstream.md`,
`add-package.md`, `update-refs.md`; fsdk-containers
`docs/skills/add-fsdk-component/SKILL.md`, `add-new-image.md`.

## Element kinds

| Kind | Produces filesystem output? | Use |
|---|---|---|
| `stack` | **No** — dependency aggregation only | Dep lists consumed by a compose |
| `compose` | Yes — filtered staging area | Layer/filter step (`include:`/`exclude:` domains) |
| `script` | Yes — via explicit commands | OCI/image assembly |
| `import` | Yes — files staged directly | Config-only / direct file placement |
| `manual` | Yes — hand-written shell | Custom builds; the only kind available in every repo |
| `junction` | No — subproject boundary | Importing freedesktop-sdk / gnome-build-meta |

Build-system kinds (`meson`, `cmake`, `autotools`, `make`) come from plugins
registered per-repo — dakota's junction graph provides them, fsdk-containers
deliberately registers none and hand-writes `kind: manual`. Check the target
repo's `project.conf` before choosing; do not assume a kind exists.

Compose filtering uses `split-rules` domains declared in elements' public
data (`format_public.md`); `compose` elements take build dependencies only —
no transient/runtime deps (`handling-files/composition.md`).

## Dependency types

| Keyword | Staged for this element's build? | Required by consumers? |
|---|---|---|
| `build-depends` | Yes | No |
| `runtime-depends` | **No** | Yes |
| `depends` (or `type: all`) | Yes | Yes |

A tool your own `build-commands`/`install-commands` invoke must be
`build-depends` or `depends`. Under `runtime-depends` it is invisible to your
sandbox and the failure surfaces as a confusing mid-build error, not a clear
"dependency missing".

## Sources and refs

- `bst source track <element>` is the only way refs are written. For
  `tar`/`remote` sources the ref is the downloaded file's sha256; for
  `git_repo` it is a git-describe string (`<tag>-<N>-g<sha>`), not a plain
  tag or SHA — never hand-write one. (Source: `downloadablefilesource.py`
  `track()`.)
- A version selector and its `ref` change **atomically**. Version-only
  automation (e.g. a Renovate bump of `v%{version}` without the ref) leaves
  the element unfetchable.
- `source track` does NOT regenerate derived source blocks (`cargo2`,
  `go_module`, vendored lock data). Regenerate them after every ref bump or
  the next cold build fails at the fetch step.
- Variables do not expand in `sources[].url:` — define URL aliases
  (conventionally `include/aliases.yml`) and reference those.
- Keep commands hermetic: no `$(date)`, `$(hostname)`, `$(curl ...)` —
  they break reproducibility and caching.

## Variables and paths

Both repos consume freedesktop-sdk, which is merged-usr and provides the
standard variables: `%{prefix}` = `/usr`, `%{bindir}` = `/usr/bin`,
`%{indep-libdir}` = `/usr/lib`, `%{sysconfdir}` = `/etc` (use sparingly),
`%{install-root}` = staging dir (prefix every install path with it).
FSDK also defines `strip-binaries`: set `strip-binaries: ""` in an element's
`variables:` whenever the payload is not ELF (fonts, configs, scripts,
pre-built tarballs) or the strip step fails the build.

## Options and conditionals

- Option names are alphanumeric + underscore only and cannot begin with a
  digit (`format_project.md`) — `my_option`, never `my-option`.
- Option *names and values are per-repo*, declared in `project.conf`. Both
  current BST repos define `arch` (`aarch64`/`x86_64`); dakota additionally
  defines `x86_64_v3` (opt-in) which fsdk-containers bans. Read
  `project.conf` before writing a conditional — a `(?):` block referencing
  an undefined option name fails at load time.
- Conditional syntax: `(?):` blocks; command-hook composition uses `(>):`
  (append), `(<):` (prepend), `(@):` (YAML include).

## Sandbox constraints

- A bare `manual` element has **no shell**: `mkdir`, `cat`, etc. fail with
  `Staged artifacts do not provide command 'sh'`. Add a shell/coreutils
  provider to `build-depends` when commands need one. `kind: script`
  assembly elements likewise do not inherit a shell from the runtime they
  stage.
- Minimal sandboxes may lack `find` — use shell globs + `case`.
- Remote-execution sandboxes may lack `/dev/stdin` (backend-dependent:
  bubblewrap-based runners mount `/proc`, the BuildBarn `bb_runner`
  chroot does not). Write inline files as:
  `install -Dm644 /dev/null target` then `cat > target <<'EOF'`.
- In container-wrapped BST invocations, artifact checkouts must use
  project-relative paths — the container only sees the repo mount.

## Overlaps and post-staging steps

`overlap-whitelist` (public data, `format_public.md`) only *permits* two
elements to ship the same path — it does not choose the winner. Staging
order decides; a `depends:` on the element shipping the original forces your
override to stage later. For deterministic replacement of a junction-owned
file, overwrite it in `integration-commands`, which run after all staging —
both repos rely on this ordering (e.g. FSDK's `integration/ldconfig.bst`
rebuilds the linker cache post-staging).
