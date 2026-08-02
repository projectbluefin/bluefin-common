#!/usr/bin/env python3
"""Validate Bluefin's ChairLift config against upstream ChairLift's schema.

ChairLift does not ignore unknown configuration keys. Upstream
internal/config/validate.go classifies any page, group, or group field name
it does not recognise as KindSchema, and internal/config/config.go::Load()
answers a KindSchema error with disabledConfig() -- every group on every
page forced off, plus a persistent "Configuration error" toast.

So a single invented key in our maintainer config does not degrade one
feature: it ships an empty application to every Bluefin user. Bluefin
preinstalls ChairLift silently at login, so nobody opts into that.

Source of truth: upstream's own config.yml, which enumerates every page and
every group and is kept in lockstep with defaultConfig() in
internal/config/config.go. Do not update the expectations in this file from
memory -- this script reads upstream directly, on purpose.

Network access is required. Set GITHUB_TOKEN (or GH_TOKEN) to avoid rate
limits; in CI, github.token is available automatically.
"""

from pathlib import Path
import os
import sys
import urllib.error
import urllib.request

import yaml

UPSTREAM_URL = (
    "https://raw.githubusercontent.com/frostyard/chairlift/main/config.yml"
)

ROOT = Path(__file__).resolve().parent.parent
OUR_CONFIG = ROOT / "system_files/shared/usr/share/chairlift/config.yml"


def fetch_upstream_schema() -> dict[str, set[str]]:
    """Return upstream's canonical page -> {group} map."""
    request = urllib.request.Request(UPSTREAM_URL)
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        request.add_header("Authorization", f"Bearer {token}")

    with urllib.request.urlopen(request, timeout=30) as response:
        raw = response.read().decode("utf-8")

    parsed = yaml.safe_load(raw)
    if not isinstance(parsed, dict) or not parsed:
        raise ValueError(f"upstream config.yml did not parse as a mapping: {raw[:200]}")

    schema: dict[str, set[str]] = {}
    for page, groups in parsed.items():
        if not isinstance(groups, dict):
            raise ValueError(f"upstream page {page!r} is not a mapping")
        schema[page] = set(groups)
    return schema


def main() -> int:
    if not OUR_CONFIG.exists():
        print(f"✗ missing {OUR_CONFIG.relative_to(ROOT)}")
        return 1

    try:
        upstream = fetch_upstream_schema()
    except (urllib.error.URLError, ValueError, yaml.YAMLError) as err:
        print(f"✗ could not read upstream ChairLift schema: {err}")
        return 1

    ours = yaml.safe_load(OUR_CONFIG.read_text(encoding="utf-8"))
    if not isinstance(ours, dict):
        print(f"✗ {OUR_CONFIG.relative_to(ROOT)} did not parse as a mapping")
        return 1

    failures: list[str] = []

    for page, groups in ours.items():
        if page not in upstream:
            failures.append(
                f'page "{page}" does not exist in ChairLift\'s schema '
                f"(known pages: {', '.join(sorted(upstream))})"
            )
            continue
        if not isinstance(groups, dict):
            failures.append(f'page "{page}" must be a mapping of groups')
            continue
        for group in groups:
            if group not in upstream[page]:
                failures.append(
                    f'group "{page}.{group}" does not exist in ChairLift\'s schema '
                    f"(known groups for {page}: {', '.join(sorted(upstream[page]))})"
                )

    for page, groups in sorted(upstream.items()):
        print(f"  {page}: {', '.join(sorted(groups))}")

    if failures:
        print()
        print("✗ ChairLift config uses keys absent from upstream's schema.")
        print("  ChairLift fails closed on unknown keys: an unrecognised page or")
        print("  group makes Load() return disabledConfig(), which disables EVERY")
        print("  feature group and shows a configuration-error toast. Remove the")
        print("  key and express the intent in a comment instead.")
        print()
        for failure in failures:
            print(f"    - {failure}")
        return 1

    print()
    print("✓ ChairLift config uses only keys upstream defines.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
