#!/usr/bin/env bats
# Tests for uwelcome + umotd integration after migration from legacy ublue-motd:
#   - system_files/shared/etc/profile.d/uwelcome.sh
#   - system_files/shared/usr/share/fish/vendor_conf.d/fish_greeting.fish
#
# Key behavioral contract: opt-out logic (formerly ~/.config/no-show-user-motd)
# is now fully delegated to uwelcome itself.
#
# profile.d and fish_greeting should invoke uwelcome unconditionally and migrate
# legacy opt-out logic.
#
# Run: bats tests/test_motd_integration.bats

bats_require_minimum_version 1.5.0

UWELCOME_PROFILE="${BATS_TEST_DIRNAME}/../system_files/shared/etc/profile.d/uwelcome.sh"
FISH_GREETING="${BATS_TEST_DIRNAME}/../system_files/shared/usr/share/fish/vendor_conf.d/fish_greeting.fish"

WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin" "${WORKDIR}/home/.config"

    # Mock uwelcome — exits 0, records args to a log
    printf '#!/usr/bin/env bash\necho "uwelcome $*" >> "%s/uwelcome.log"\n' \
        "${WORKDIR}" > "${WORKDIR}/bin/uwelcome"
    chmod +x "${WORKDIR}/bin/uwelcome"

    export HOME="${WORKDIR}/home"
    export PATH="${WORKDIR}/bin:${PATH}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# profile.d/uwelcome.sh — bash/zsh terminal MOTD
# ---------------------------------------------------------------------------

@test "uwelcome.sh: invokes uwelcome" {
    run bash "${UWELCOME_PROFILE}"
    [ "${status}" -eq 0 ]
    [ -f "${WORKDIR}/uwelcome.log" ]
}


# @test "uwelcome.sh: migrates legacy opt-out and still runs uwelcome" {
@test "uwelcome.sh: migrates legacy opt-out and still runs uwelcome" {
    touch "${HOME}/.config/no-show-user-motd"
    run bash "${UWELCOME_PROFILE}"
    [ "${status}" -eq 0 ]
    # Legacy marker is consumed, not left behind to retry every login
    [ ! -e "${HOME}/.config/no-show-user-motd" ]
    [ -e "${HOME}/.config/uwelcome/disabled" ]
    # uwelcome is invoked unconditionally; it owns the opt-out decision
    [ -f "${WORKDIR}/uwelcome.log" ]
}

@test "uwelcome.sh: does not call legacy ublue-motd" {
    run grep 'ublue-motd' "${UWELCOME_PROFILE}"
    [ "${status}" -ne 0 ]
}

# ---------------------------------------------------------------------------
# fish_greeting.fish — fish terminal MOTD (static content checks)
# Fish is not required in CI; these are grep-based structural assertions.
# ---------------------------------------------------------------------------

@test "fish_greeting: function body calls uwelcome" {
    grep -q 'uwelcome' "${FISH_GREETING}"
}

# @test "fish_greeting.fish: migrates legacy opt-out and still runs uwelcome" {
@test "fish_greeting.fish: migrates legacy opt-out and still runs uwelcome" {
    touch "${HOME}/.config/no-show-user-motd"
    run fish "${FISH_GREETING}"
    [ "${status}" -eq 0 ]
    # Legacy marker is consumed, not left behind to retry every login
    [ ! -e "${HOME}/.config/no-show-user-motd" ]
    [ -e "${HOME}/.config/uwelcome/disabled" ]
    # uwelcome is invoked unconditionally; it owns the opt-out decision
    [ -f "${WORKDIR}/uwelcome.log" ]
}

@test "fish_greeting: does not call legacy ublue-motd" {
    run grep 'ublue-motd' "${FISH_GREETING}"
    [ "${status}" -ne 0 ]
}
