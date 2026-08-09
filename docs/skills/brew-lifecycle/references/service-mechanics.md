# Service Mechanics — brew-lifecycle

Part of [brew-lifecycle](../SKILL.md) — how brew-preinstall.service works, state file format, the per-login flow, the long-time-user removal scenario, bonedigger-report integration, variant-specific Brewfiles, merging order, and path conventions.

---

## How brew-preinstall works

**Brew is not installed in the OCI image.** The Containerfile is Alpine-based
and only assembles `/out/` directories (wallpapers, completions, udev rules,
binaries). The image ships the Brewfiles and the `brew-preinstall.service`
systemd unit. The actual brew packages are installed at **first user login**.

### Service

`brew-preinstall.service` is a user-level oneshot that fires after
`network-online.target` and `ublue-user-setup.service`. It is enabled globally
via `usr/lib/systemd/user-preset/01-brew-preinstall.preset`. Downstream repos
do **not** need `systemctl --global enable` calls. The service only runs when
brew is installed at `/var/home/linuxbrew/.linuxbrew/bin/brew`.

### State file

`~/.local/share/ublue-os/brew-preinstall-state.json`
```json
{ "hash": "<sha256 of all Brewfiles combined>", "packages": ["pkg1", ...] }
```

### On every login

1. Hash all `preinstall.d/*.Brewfile` files combined.
2. Compare to stored hash. **Identical → fast exit**, nothing touched.
3. **Different:** run `brew bundle --file=` on each Brewfile (idempotent).
4. Diff `previous_packages` (from state JSON) against `current_packages`
   (from Brewfiles). Uninstall packages that were in the old set but not
   the new one — **only if `brew list` confirms they are installed**.
5. Write new hash + package list to state file atomically (tmp + mv).

**The service is content-addressed, not version-numbered.** Never bump a
counter to propagate a Brewfile change — just edit the file. The hash change
triggers re-run automatically.

**Safety rule:** the uninstall step only removes packages that were in the
*previous managed state file*. If a user independently ran `brew install inxi`
themselves, it is not in their state file's managed list and will never be
touched.

### What happens to long-time users on a package removal

Example: user has been running Bluefin since before `inxi`/`nvtop` were removed.
Their state file lists them in `packages`. On next login after the OS update:

1. Hash changes (Brewfile content changed) → triggers
2. `brew bundle` runs new 11-package list (no-ops for already-installed)
3. Diff: `previous = [..., inxi, nvtop, ...]`, `current = [...]` → `removed = [inxi, nvtop]`
4. `brew list inxi` → installed → `brew uninstall inxi --ignore-dependencies`
5. `brew list nvtop` → installed → `brew uninstall nvtop --ignore-dependencies`
6. State file updated with new hash + 11-package list

Result: packages are **silently removed on the next login**. No prompt.

---

## Adding and removing packages — the exact steps

### Add a variant-specific Brewfile

Downstream repos can ship their own Brewfiles by dropping `*.Brewfile` files
into the same `preinstall.d/` directory in `system_files/<variant>/`. All
`*.Brewfile` files in the directory are hashed, bundled, and tracked together.

---

## Confirming the service is working — bonedigger-report

`bonedigger-report` (`ujust report`) captures `systemctl list-units --state=failed`.
If `brew-preinstall.service` fails for a user, it appears in the **Failed Systemd
Units** section of their gist report. This is the primary signal available today.

**What is not captured today:**
- The brew-preinstall state file contents (`~/.local/share/ublue-os/brew-preinstall-state.json`)
- The brew-preinstall journal log (success path, hash, packages installed/removed)
- Whether the service ran successfully vs was skipped (brew not installed)

To add brew-preinstall health to bonedigger-report, append to the summary block
in `system_files/bluefin/usr/libexec/bonedigger-report`:
```bash
BREW_STATE="$(cat ~/.local/share/ublue-os/brew-preinstall-state.json 2>/dev/null || echo 'state file absent')"
BREW_SVC_STATUS="$(systemctl --user is-active brew-preinstall.service 2>/dev/null || echo unknown)"
BREW_SVC_LOG="$(journalctl --user -u brew-preinstall.service --no-pager -n 20 2>/dev/null || true)"
```
Then include these in the report markdown. This would let maintainers see at
a glance whether the service ran, which hash it applied, and what it installed.

---

## Merging order for the factory

When adding a package that spans multiple repos, merge in this order:

1. `projectbluefin/common` — add/remove from `preinstall.d/system-cli.Brewfile`
2. `projectbluefin/bluefin` — remove the RPM from `03-packages.sh`
3. `projectbluefin/bluefin-lts` — remove from `build_scripts/packages/base.toml`
4. `projectbluefin/dakota` — remove the `.bst` element from `elements/bluefin/`
   and its entry from `elements/bluefin/deps.bst`

The common PR must land first — downstream PRs depend on the service being
present in the image they consume.

---

## Path convention

Keep the real implementation in `/usr/libexec/brew-preinstall` and leave
`/usr/bin/brew-preinstall` as a thin compatibility wrapper. This matches
the bootc/FHS split: internal image helpers in `/usr/libexec`, user-facing
commands in `/usr/bin`, static Brewfiles in `/usr/share`.
