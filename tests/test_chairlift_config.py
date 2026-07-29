"""Regression checks for the ChairLift config and preinstall Brewfile.

ChairLift (https://github.com/frostyard/chairlift) reads
/usr/share/chairlift/config.yml for maintainer defaults. These tests pin
the Bluefin decisions: frostyard/chairlift#54 resolved via the
system-integration split (frostyard/chairlift#102), so bootc staging is
now backed by an image-side polkit policy and stage script and
bootc_updates_group is enabled. updex (features_group) stays disabled
because no updex helper ships on Bluefin. Bundle paths point at Bluefin's
Brewfiles, and help links point at Bluefin resources.
"""

from pathlib import Path

import yaml


ROOT = Path(__file__).parent.parent
CONFIG = ROOT / "system_files/shared/usr/share/chairlift/config.yml"
BREWFILE = (
    ROOT
    / "system_files/shared/usr/share/ublue-os/homebrew/preinstall.d/chairlift.Brewfile"
)
BOOTC_POLICY = (
    ROOT
    / "system_files/shared/usr/share/polkit-1/actions"
    / "org.frostyard.ChairLift.bootc.policy"
)
BOOTC_STAGE_SCRIPT = ROOT / "system_files/shared/usr/libexec/bootc-update-stage"

# Pages and groups documented in upstream CONFIG.md. Anything outside this
# set is silently ignored by ChairLift, so it is a typo until proven otherwise.
KNOWN_GROUPS = {
    "system_page": {"system_info_group", "bootc_status_group", "health_group"},
    "updates_page": {
        "bootc_updates_group",
        "flatpak_updates_group",
        "brew_updates_group",
        "brew_trust_group",
        "updates_settings_group",
    },
    "applications_page": {
        "applications_installed_group",
        "flatpak_user_group",
        "flatpak_system_group",
        "brew_group",
        "brew_search_group",
        "brew_bundles_group",
    },
    "maintenance_page": {
        "maintenance_cleanup_group",
        "maintenance_brew_group",
        "maintenance_flatpak_group",
        "maintenance_optimization_group",
    },
    "features_page": {"features_group"},
    "help_page": {"help_resources_group"},
}


def _load_config():
    return yaml.safe_load(CONFIG.read_text(encoding="utf-8"))


def test_config_parses_and_uses_known_pages_and_groups():
    data = _load_config()
    assert isinstance(data, dict)

    for page, groups in data.items():
        assert page in KNOWN_GROUPS, f"unknown page: {page}"
        assert isinstance(groups, dict)
        for group, settings in groups.items():
            assert group in KNOWN_GROUPS[page], f"unknown group: {page}.{group}"
            assert isinstance(settings, dict)
            assert isinstance(settings.get("enabled"), bool), (
                f"{page}.{group} must set enabled: true/false"
            )


def test_bootc_staging_enabled_now_that_polkit_glue_ships():
    """frostyard/chairlift#54 resolved via the system-integration split
    (frostyard/chairlift#102): Bluefin now ships the fixed
    /usr/libexec/bootc-update-stage helper and the bootc polkit policy, so
    bootc_updates_group can be enabled."""
    data = _load_config()
    assert data["updates_page"]["bootc_updates_group"]["enabled"] is True


def test_updex_features_group_stays_disabled():
    """updex has no Bluefin helper yet, independent of the bootc polkit
    fix. Keep it off until updex actually ships on Bluefin."""
    data = _load_config()
    assert data["features_page"]["features_group"]["enabled"] is False


def test_bootc_stage_polkit_policy_pins_fixed_helper_path():
    """The polkit action must annotate the exact fixed path ChairLift's
    pkexec invocation expects; auth is still required (auth_admin), so no
    passwordless rules.d bypass should exist alongside it."""
    content = BOOTC_POLICY.read_text(encoding="utf-8")
    assert "org.frostyard.ChairLift.bootc.stage" in content
    assert (
        '<annotate key="org.freedesktop.policykit.exec.path">'
        "/usr/libexec/bootc-update-stage</annotate>" in content
    )
    assert "<allow_any>auth_admin</allow_any>" in content


def test_bootc_stage_script_is_executable_and_stages_only():
    """The privileged helper must only stage (never auto-apply/reboot) so
    uupd remains the sole owner of when an update actually takes effect."""
    assert BOOTC_STAGE_SCRIPT.stat().st_mode & 0o111, (
        "bootc-update-stage must be executable"
    )
    exec_lines = [
        line
        for line in BOOTC_STAGE_SCRIPT.read_text(encoding="utf-8").splitlines()
        if line.strip().startswith("exec ")
    ]
    assert len(exec_lines) == 1, "expected exactly one exec invocation"
    (exec_line,) = exec_lines
    assert "bootc upgrade" in exec_line
    assert "--download-only" in exec_line
    assert "--apply" not in exec_line


def test_update_policy_stays_with_uupd():
    """Bluefin updates are silent and background-staged by uupd; the user
    reboots on their own schedule. ChairLift must not surface update
    scheduling knobs that compete with uupd or prompt the user."""
    data = _load_config()
    assert data["updates_page"]["updates_settings_group"]["enabled"] is False


def test_bundles_paths_point_at_bluefin_brewfiles():
    group = _load_config()["applications_page"]["brew_bundles_group"]
    assert group["bundles_paths"] == ["/usr/share/ublue-os/homebrew"]


def test_help_links_point_at_bluefin():
    resources = _load_config()["help_page"]["help_resources_group"]
    for key in ("website", "issues", "chat"):
        assert resources[key].startswith("https://"), f"{key} must be https"
        assert "projectbluefin.io" in resources[key], (
            f"{key} must point at a Bluefin resource"
        )


def test_brewfile_taps_frostyard_with_trust():
    """Homebrew 6 blocks untrusted taps silently; trusted: true is load-bearing."""
    content = BREWFILE.read_text(encoding="utf-8")
    assert 'tap "frostyard/tap", trusted: true' in content
    assert 'cask "chairlift"' in content
