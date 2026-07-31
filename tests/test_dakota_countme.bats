#!/usr/bin/env bats

SCRIPT_UNDER_TEST="$BATS_TEST_DIRNAME/../system_files/shared/usr/libexec/dakota-countme"
SERVICE_UNIT="$BATS_TEST_DIRNAME/../system_files/shared/usr/lib/systemd/system/dakota-countme.service"
TIMER_UNIT="$BATS_TEST_DIRNAME/../system_files/shared/usr/lib/systemd/system/dakota-countme.timer"

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin"
}

teardown() {
    rm -rf "${WORKDIR}"
}

@test "dakota-countme: exits before checking dependencies when disabled" {
    touch "${WORKDIR}/disabled"

    run env PATH="${WORKDIR}/bin" DISABLED_FILE="${WORKDIR}/disabled" \
        "${BASH}" "${SCRIPT_UNDER_TEST}"

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "dakota-countme: safely skips when jq is unavailable" {
    printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "${WORKDIR}/bin/curl"
    chmod +x "${WORKDIR}/bin/curl"

    run env PATH="${WORKDIR}/bin" "${BASH}" "${SCRIPT_UNDER_TEST}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"jq is unavailable; skipping telemetry"* ]]
}

@test "dakota-countme: safely skips when curl is unavailable" {
    printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "${WORKDIR}/bin/jq"
    chmod +x "${WORKDIR}/bin/jq"

    run env PATH="${WORKDIR}/bin" "${BASH}" "${SCRIPT_UNDER_TEST}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"curl is unavailable; skipping telemetry"* ]]
}

@test "dakota-countme: units honor the documented opt-out file" {
    grep -Fx 'ConditionPathExists=!/etc/dakota-countme/disabled' "${SERVICE_UNIT}"
    grep -Fx 'ConditionPathExists=!/etc/dakota-countme/disabled' "${TIMER_UNIT}"
}
