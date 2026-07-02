---
name: bazaar
version: "2.0"
last_updated: "2026-07-01"
tags: [bazaar, curated, flatpak, apps]
description: "Use when editing Bazaar curated config, systemd service definitions, or hooks in common. Covers the new curated schema (post-0.8.3), sRGB JXL-to-PNG image conversions, Type=simple requirements, and local ujust preview workflows."
metadata:
  type: procedure
  context7-sources:
    - /flatpak/flatpak-docs
---

# Bazaar — curated config and hook operations

## When to use

- Editing Bazaar config in `system_files/bluefin/etc/bazaar/`
- Porting curated-page structure across Bazaar schema versions
- Changing Bazaar hook behavior for app install interception
- Validating Bazaar behavior locally before opening a PR
- Modifying the background `bazaar.service` systemd service definition

## When NOT to use

- Editing general Flatpak preferences or system-wide flatpak overrides unrelated to Bazaar's hooks or configuration.

## Files and ownership

| File | Purpose |
|---|---|
| `system_files/bluefin/etc/bazaar/bazaar.yaml` | Bazaar runtime config, config paths, hook wiring |
| `system_files/bluefin/etc/bazaar/curated.yaml` | Curated Explore content (sections, banners, articles, carousels) |
| `system_files/bluefin/etc/bazaar/blocklist.yaml` | Bluefin blocklist policy |
| `system_files/bluefin/etc/bazaar/hooks.py` | Host-side hook script invoked by Bazaar |
| `system_files/bluefin/usr/libexec/bazaar-hook` | In-image hook script used by Bazaar runtime path |
| `system_files/bluefin/usr/lib/systemd/user/bazaar.service` | Background Bazaar service entrypoint |
| `tests/test_hooks.py` | `hooks.py` state machine tests |
| `tests/test_bazaar_hook.py` | `bazaar-hook` state machine tests |
| `tests/test_curated_config.py` | Curated/Bazaar config shape regression checks |

## Curated schema — current format (post-0.8.3 / PR #1655)

Bazaar upstream merged **PR #1655 "Rework Curated System"** on 2026-06-23. This is a **breaking schema change**. Bluefin `curated.yaml` has been migrated to the new format.

**Current schema uses typed row entries:**
```yaml
rows:
  - banner:
      height: 400
      image:
        light-uri: file:///run/host/etc/bazaar/11-bluefin-day.png
        dark-uri: file:///run/host/etc/bazaar/11-bluefin-night.png
        fit: cover
        can-shrink: true
        alt: "Bluefin desktop screenshot"
      light-color: "#a5897b"
      dark-color: "#0d0e19"
  - section:
      title: "Bluefin Recommends"
      subtitle:
        string: "Our Favorite Applications"
      appids:
        list:
          - org.gnome.Calculator
```

**Key schema rules:**
- Root `css:` block does NOT exist in the new schema — remove it entirely.
- `rows` is a list of typed entries: `banner`, `section`, `articles`, `featured-carousel`.
- Each entry has exactly one key (`banner:`, `section:`, etc.).
- `section.subtitle` is a markdown object: `subtitle: string: "..."` (not a plain string).
- `section.appids` is `appids: list: [...]` (not a bare list).
- `banner` and `section` are separate rows — one banner per section, both as siblings in `rows`.
- `section.overflow-count` enables a "Show More" button for sections with many apps.

### Compatibility note

Stable Bazaar `v0.8.2` and earlier still expect the legacy schema (`css:` plus `rows[].sections[].category`). When targeting those older releases, port content back to the legacy shape. Always verify the installed Bazaar version before editing.

## Banner image conversion (JXL → PNG)

Banner images in `bluefin-branding/system_files/etc/bazaar/` are stored as `.jxl`. They are converted to `.png` at build time in the `Containerfile` using `djxl` with `--color_space=sRGB`.

**Containerfile pattern:**
```dockerfile
RUN set -e && mkdir -p /out/bluefin/etc/bazaar && \
    for f in /tmp/bazaar-banners/*.jxl; do \
      name=$(basename "$f" .jxl); \
      djxl "$f" "/out/bluefin/etc/bazaar/${name}.png" --color_space=sRGB; \
    done
```

**Critical rules:**
- `curated.yaml` must reference `.png` paths, never `.jxl` — Bazaar crashes on JXL due to a libdex fiber scheduling regression on modern GNOME runtimes.
- The correct djxl flag is `--color_space=sRGB` (long form). The short form `-C` does not exist in the `libjxl-tools` version used in the Alpine build stage — using it causes "Unknown argument" error and a silent build failure.
- The `RUN` step **must** include `set -e`. Without it, a `djxl` failure silently exits 0 — the build passes, the PNG is missing, and the curated page breaks at runtime.

## bazaar.service requirements

`bazaar.service` must be `Type=simple` with `Restart=on-failure`. The `bazaar --no-window` process runs as a persistent background daemon.

```ini
[Service]
Type=simple
ExecStart=flatpak run --command=bazaar io.github.kolunmi.Bazaar --no-window
StandardOutput=journal
Restart=on-failure
RestartSec=5
```

`Type=oneshot` causes `systemctl` to hang indefinitely waiting for the service to exit.

## Local preview workflow

Since the curated layout references PNG banners (converted from JXL files inside the branding submodule), the local environment needs those PNGs to exist in `/etc/bazaar` on the host to avoid rendering blank spaces.

Always use the automated preview recipes which handle JXL conversion via a non-root `podman` container and reload the systemd service:

### From the checked-out workspace:
```bash
# Formats, builds/converts JXL banners to PNG, copies all config files to /etc/bazaar, and restarts the service
just bazaar-preview
```

### From any terminal on a dev machine (targeting a common checkout directory):
```bash
ujust bazaar-preview /path/to/common
```

## Common Pitfalls & Rationalizations

- **"I can just run djxl locally."** -> This fails in CI and on many developer machines because `djxl` is not installed on the host. Always use the automated `podman` JXL-to-PNG loop.
- **"I'll use the legacy -C sRGB flag."** -> Newer versions of `djxl` throw `Unknown argument: -C` and abort the build. Always use `--color_space=sRGB` to preserve full sRGB pixel colors.
- **"Using Type=oneshot on bazaar.service is fine."** -> If the systemd service is `oneshot`, and the command `bazaar --no-window` runs as a persistent daemon, systemd will block forever waiting for the service to start, hanging the user's terminal. Always use `Type=simple`.
- Editing curated content without local preview causes UI regressions to slip through.
- Changing hook dialog/response IDs must be mirrored in tests to avoid silent behavior drift.
- Dropping `set -e` from the JXL conversion RUN step lets silent build failures through.

## Red Flags

- `curated.yaml` contains root `css:` key — this is the old schema; migrate to `rows` with `banner`/`section` types.
- `curated.yaml` uses `rows[].sections[].category` structure — old schema; migrate to new typed rows.
- Banner entries reference `.jxl` paths instead of `.png`.
- `bazaar.service` has `Type=oneshot` or `RemainAfterExit=yes` — will hang `systemctl` indefinitely.
- `Containerfile` JXL conversion loop is missing `set -e` — silent build failures produce no PNG.
- `djxl` invocation uses `-C sRGB` — this flag does not exist; use `--color_space=sRGB`.
- `section.subtitle` is a bare string — must be `subtitle: string: "..."`.
- `section.appids` is a bare list — must be `appids: list: [...]`.

## Verification

Before declaring a Bazaar task complete, ensure:
- [ ] `curated.yaml` uses new schema: `rows[]` with `banner`/`section` row types, no root `css`
- [ ] All banner `uri`/`light-uri`/`dark-uri` entries end in `.png`
- [ ] All `section` entries have `title` and `appids.list`
- [ ] `bazaar.service` is `Type=simple` with `Restart=on-failure`
- [ ] `Containerfile` JXL conversion `RUN` step begins with `set -e`
- [ ] `djxl` invocation uses `--color_space=sRGB` (not `-C sRGB`)
- [ ] `python3 -m pytest tests/test_curated_config.py -v` passes
- [ ] `just check && pre-commit run --all-files` passes
