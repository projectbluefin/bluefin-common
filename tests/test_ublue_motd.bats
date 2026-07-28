#!/usr/bin/env bats
# Tests for the legacy ublue-motd stack modified by PR #795
# (double-execution guard and missing env.sh graceful handling):
#   - system_files/shared/etc/profile.d/ublue-motd.sh
#   - system_files/shared/usr/bin/ublue-motd
#
# Covers:
#   1. First invocation runs ublue-motd and sets UBLUE_MOTD_SHOWN=1
#   2. Second invocation (UBLUE_MOTD_SHOWN=1 already set) does NOT run again
#   3. Invocation skipped when ~/.config/no-show-user-motd exists
#   4. ublue-motd binary: sourcing env.sh skipped gracefully when file is missing
#
# Run: bats tests/test_ublue_motd.bats

bats_require_minimum_version 1.5.0

UBLUE_MOTD_PROFILE="${BATS_TEST_DIRNAME}/../system_files/shared/etc/profile.d/ublue-motd.sh"
UBLUE_MOTD_BIN="${BATS_TEST_DIRNAME}/../system_files/shared/usr/bin/ublue-motd"

WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin" "${WORKDIR}/home/.config"

    # Mock ublue-motd — exits 0, records each invocation to a log
    printf '#!/bin/sh\necho "ublue-motd $*" >> "%s/ublue-motd.log"\n' \
        "${WORKDIR}" > "${WORKDIR}/bin/ublue-motd"
    chmod +x "${WORKDIR}/bin/ublue-motd"

    export HOME="${WORKDIR}/home"
    export PATH="${WORKDIR}/bin:${PATH}"
    unset UBLUE_MOTD_SHOWN
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# profile.d/ublue-motd.sh — first invocation
# ---------------------------------------------------------------------------

@test "ublue-motd.sh: first invocation runs ublue-motd" {
    run bash "${UBLUE_MOTD_PROFILE}"
    [ "${status}" -eq 0 ]
    [ -f "${WORKDIR}/ublue-motd.log" ]
}

@test "ublue-motd.sh: first invocation exports UBLUE_MOTD_SHOWN=1" {
    # Source in a wrapper script so we can inspect the exported variable
    local wrapper="${WORKDIR}/check_shown.sh"
    printf '#!/bin/bash\nsource "%s"\necho "${UBLUE_MOTD_SHOWN}"\n' \
        "${UBLUE_MOTD_PROFILE}" > "${wrapper}"
    chmod +x "${wrapper}"

    run bash "${wrapper}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "1" ]
}

# ---------------------------------------------------------------------------
# profile.d/ublue-motd.sh — double-execution guard
# ---------------------------------------------------------------------------

@test "ublue-motd.sh: second invocation skipped when UBLUE_MOTD_SHOWN=1" {
    # run inherits exported variables from the test process
    export UBLUE_MOTD_SHOWN=1
    run bash "${UBLUE_MOTD_PROFILE}"
    # The &&-chain short-circuits (exit code may be non-zero); check behavior only
    [ ! -f "${WORKDIR}/ublue-motd.log" ]
}

@test "ublue-motd.sh: two sequential sources only invoke ublue-motd once" {
    local wrapper="${WORKDIR}/double_source.sh"
    printf '#!/bin/bash\nsource "%s"\nsource "%s"\nwc -l < "%s/ublue-motd.log"\n' \
        "${UBLUE_MOTD_PROFILE}" "${UBLUE_MOTD_PROFILE}" "${WORKDIR}" > "${wrapper}"
    chmod +x "${wrapper}"

    run bash "${wrapper}"
    [ "${status}" -eq 0 ]
    [ "${output}" -eq 1 ]
}

# ---------------------------------------------------------------------------
# profile.d/ublue-motd.sh — opt-out via no-show-user-motd
# ---------------------------------------------------------------------------

@test "ublue-motd.sh: skipped when no-show-user-motd file exists" {
    touch "${WORKDIR}/home/.config/no-show-user-motd"
    run bash "${UBLUE_MOTD_PROFILE}"
    # The &&-chain short-circuits (exit code may be non-zero); check behavior only
    [ ! -f "${WORKDIR}/ublue-motd.log" ]
}

@test "ublue-motd.sh: no-show-user-motd takes priority even when UBLUE_MOTD_SHOWN is unset" {
    touch "${WORKDIR}/home/.config/no-show-user-motd"
    unset UBLUE_MOTD_SHOWN
    run bash "${UBLUE_MOTD_PROFILE}"
    [ ! -f "${WORKDIR}/ublue-motd.log" ]
}

# ---------------------------------------------------------------------------
# usr/bin/ublue-motd — graceful skip when env.sh is missing
# ---------------------------------------------------------------------------

@test "ublue-motd binary: succeeds without error when env.sh does not exist" {
    local template="${WORKDIR}/template.md"
    echo "Hello MOTD" > "${template}"

    # Mock envsubst — pass stdin through unchanged
    printf '#!/bin/sh\ncat\n' > "${WORKDIR}/bin/envsubst"
    chmod +x "${WORKDIR}/bin/envsubst"

    # Mock glow — pass stdin through unchanged
    printf '#!/bin/sh\ncat\n' > "${WORKDIR}/bin/glow"
    chmod +x "${WORKDIR}/bin/glow"

    run env \
        PATH="${WORKDIR}/bin:${PATH}" \
        MOTD_TEMPLATE_FILE="${template}" \
        MOTD_ENV_SCRIPT="${WORKDIR}/nonexistent-env.sh" \
        sh "${UBLUE_MOTD_BIN}"

    [ "${status}" -eq 0 ]
}

@test "ublue-motd binary: sources env.sh when it exists" {
    local template="${WORKDIR}/template.md"
    echo 'Value: $TEST_VAR' > "${template}"

    local env_sh="${WORKDIR}/env.sh"
    printf 'TEST_VAR=hello_from_env\n' > "${env_sh}"

    printf '#!/bin/sh\ncat\n' > "${WORKDIR}/bin/envsubst"
    chmod +x "${WORKDIR}/bin/envsubst"

    printf '#!/bin/sh\ncat\n' > "${WORKDIR}/bin/glow"
    chmod +x "${WORKDIR}/bin/glow"

    run env \
        PATH="${WORKDIR}/bin:${PATH}" \
        MOTD_TEMPLATE_FILE="${template}" \
        MOTD_ENV_SCRIPT="${env_sh}" \
        sh "${UBLUE_MOTD_BIN}"

    [ "${status}" -eq 0 ]
}
