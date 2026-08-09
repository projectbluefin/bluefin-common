---
name: brew-lifecycle
version: "1.2"
last_updated: "2026-08-09"
id: brew-lifecycle
one_line_purpose: Manage OS-managed Homebrew packages and RPM/brew placement.
entry_point: docs/skills/brew-lifecycle/SKILL.md
category: ci-ops
mcp_compliance_level: partial
optimization_status: draft
status: active
dependencies: []
tags: [brew, homebrew, packages]
description: >-
  Manage OS-managed Homebrew packages. Use when adding/removing default brew
  packages, moving tools between RPM and brew, or auditing image-vs-brew
  placement.
metadata:
  type: procedure
  context7-sources:
    - /bootc-dev/bootc
    - /homebrew/brew
---

# brew-lifecycle — Homebrew Package Lifecycle for Bluefin

How to add, remove, and manage system-default Homebrew packages across
the Bluefin factory. Covers the brew-preinstall service, the preinstall.d
pattern, and the rules for what can and cannot move to brew.

---

## When to Use

- Adding or removing a package from `preinstall.d/system-cli.Brewfile`
- Moving a self-contained CLI tool off the RPM image and into brew
- Adding or removing a tap (`trusted: true` requirements, Brewfile syntax)
- Debugging a failed or skipped `brew-preinstall.service`
- Deciding whether a new tool belongs on the image or in a Brewfile
- Auditing image diet (removing dead-weight packages from bluefin/lts/dakota)

## When NOT to Use

- Installing system-level packages (udev rules, kernel modules, daemons, firmware): those stay on the image as RPMs regardless
- `rpm-ostree install` is never the answer — see [placement-rules.md](references/placement-rules.md)
- Adding user-installed (opt-in) packages: those go in the opt-in Brewfiles (`cli.Brewfile`, `cncf.Brewfile`, etc.), not `preinstall.d/`

---

## Adding and removing packages — the exact steps

### Add a package
1. Add a `brew "<name>"` line to
   `system_files/shared/usr/share/ublue-os/homebrew/preinstall.d/system-cli.Brewfile`
2. Open a PR. No version bumping, no manual trigger.
3. On next login after the OS update, every user gets the package installed.

### Remove a package
1. Remove the `brew "<name>"` line from the Brewfile.
2. Open a PR.
3. On next login after the OS update, users who got it through the managed set
   get it uninstalled. Users who installed it themselves are unaffected.

### Add or remove a cask

Use `cask "<name>"` in a managed Brewfile. The service installs casks through
the existing `brew bundle` pass, tracks them separately in the state file, and
uses `brew uninstall --cask` when a managed cask is removed.

The repository validator and lifecycle parser accept indentation and either
Ruby quote style:

```ruby
cask "chairlift"
cask 'chairlift'
```

Legacy state files without a `casks` key require no migration.

### Add a tap + package from a non-core tap

Homebrew 6.0 syntax — `trusted: true` is required:
```ruby
tap "projectbluefin/bluefinctl", trusted: true
brew "bluefinctl"
```
Without `trusted: true` the tap is blocked and the formula is silently
unavailable. See [placement-rules.md](references/placement-rules.md#homebrew-60-tap-trust-required-as-of-2026-06-11).

### Brewfile placement rule

Any package that installs on ALL variants must live in `system_files/shared/preinstall.d/`,
not `system_files/bluefin/preinstall.d/`. See [package-set.md](references/package-set.md#brewfile-scope-shared-vs-bluefin-for-all-variant-packages).

---

## Red Flags

- Suggesting `rpm-ostree install` for any missing tool — this is never correct on Bluefin
- Adding a package to `preinstall.d/` that has a udev rule, kernel module, D-Bus system service, FUSE driver, firmware, or PAM dependency — it must stay as an RPM
- Adding a tap without `trusted: true` / `--trust` (Homebrew 6.0 blocks untrusted taps silently)
- Bumping a version number or manual stamp to "trigger" a brew-preinstall re-run — the service is content-addressed; edit the Brewfile and the hash change triggers it automatically
- Writing lifecycle code that advances the state hash after a failed bundle or uninstall — failures must leave state unchanged so the next login retries
- Editing `preinstall.d/` in a downstream repo (bluefin, bluefin-lts, dakota) for packages that should live in `common` — common ships to all variants
- Assuming `brew-preinstall.service` ran successfully because it's enabled — the service exits 0 silently if brew is not yet installed; check `journalctl --user -u brew-preinstall.service`

## Verification

After any change to `preinstall.d/` or `brew-preinstall`:

- [ ] Package obeys the "can move to brew" rule: self-contained CLI, no system-level deps
- [ ] If adding a tap: `trusted: true` in the Brewfile line (Homebrew 6.0)
- [ ] If adding a cask: it is recorded under `.casks` and removal uses `brew uninstall --cask`
- [ ] Bundle and uninstall failures leave the previous state hash intact for retry
- [ ] `pre-commit run --all-files` passes (Brewfile format, YAML/TOML hygiene)
- [ ] `just test` passes (bats tests in `tests/test_brew_preinstall.bats`)
- [ ] If removing a package: confirmed it was in the previous managed state — it will be auto-uninstalled for existing users on next login
- [ ] Merging order followed if the change spans repos: common → bluefin → bluefin-lts → dakota

## References

| File | Contents |
|---|---|
| [package-set.md](references/package-set.md) | Current 11-package default set, what belongs in preinstall.d, fzf/ujust bootstrap, opt-in Brewfiles, shared/ vs bluefin/ placement rule |
| [service-mechanics.md](references/service-mechanics.md) | How brew-preinstall.service works, state file format, login flow, long-time user removal scenario, bonedigger-report integration, merging order, path convention |
| [placement-rules.md](references/placement-rules.md) | No rpm-ostree rule, what can move to brew, Homebrew 6.0 tap trust details, Starship shell initialization |
