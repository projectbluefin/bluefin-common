#!/usr/bin/env bats

SCRIPT_UNDER_TEST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/bin/ublue-image-info.sh"
WORKDIR=""
MOCKDIR=""
FIXTURE=""

setup() {
    WORKDIR="${BATS_TEST_DIRNAME}/.test_ublue_image_info.$$.$RANDOM"
    rm -rf "${WORKDIR}"
    MOCKDIR="${WORKDIR}/bin"
    FIXTURE="${WORKDIR}/image-info.json"

    mkdir -p "${MOCKDIR}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

write_mock() {
    local name="$1"
    local body="$2"

    printf '%s\n' "${body}" > "${MOCKDIR}/${name}"
    chmod +x "${MOCKDIR}/${name}"
}

write_jq_mock() {
    write_mock "jq" '#!/usr/bin/bash
/usr/bin/jq "$@"'
}

write_rpm_ostree_mock() {
    local body="$1"

    write_mock "rpm-ostree" "#!/usr/bin/bash
${body}"
}

write_image_info_fixture() {
    local image_name="$1"
    local image_tag="$2"

    cat > "${FIXTURE}" <<EOF
{
  "image-name": "${image_name}",
  "image-tag": "${image_tag}"
}
EOF
}

write_bootc_mock() {
    local booted_image="$1"

    write_mock "bootc" "#!/usr/bin/bash
if [[ \"\$*\" == \"status --json\" ]]; then
    echo '{\"status\":{\"booted\":{\"image\":{\"image\":{\"image\":\"${booted_image}\",\"transport\":\"registry\"}}}}}'
fi"
}

run_script() {
    local image_info_file="$1"
    local path_value="$2"

    run env IMAGE_INFO_FILE="${image_info_file}" PATH="${path_value}" /usr/bin/bash "${SCRIPT_UNDER_TEST}"
}

@test "ublue-image-info: prints image name, tag, and locked status with fixture data" {
    write_jq_mock
    write_rpm_ostree_mock 'echo "State: booted deployment signed"'
    write_image_info_fixture "bluefin" "latest"

    run_script "${FIXTURE}" "${MOCKDIR}:${PATH}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "bluefin:latest 🔐" ]
}

@test "ublue-image-info: shows unlocked status when rpm-ostree output lacks signed marker" {
    write_jq_mock
    write_rpm_ostree_mock 'echo "State: booted deployment"'
    write_image_info_fixture "bluefin" "latest"

    run_script "${FIXTURE}" "${MOCKDIR}:${PATH}"

    [ "${status}" -eq 0 ]
    [ "${output}" = $'bluefin:latest \033[5m🔓\033[0m' ]
}

@test "ublue-image-info: handles missing image-info.json without failing" {
    write_jq_mock
    write_rpm_ostree_mock 'echo "State: booted deployment signed"'

    run_script "${WORKDIR}/missing-image-info.json" "${MOCKDIR}:${PATH}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"${WORKDIR}/missing-image-info.json: No such file or directory"* ]]
    [[ "${output}" == *" 🔐" ]]
}

@test "ublue-image-info: handles missing jq without failing" {
    write_rpm_ostree_mock 'echo "State: booted deployment signed"'
    write_image_info_fixture "bluefin" "latest"

    run_script "${FIXTURE}" "${MOCKDIR}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"jq: command not found"* ]]
    [[ "${output}" == *" 🔐" ]]
}

@test "ublue-image-info: uses live tag from bootc status when available" {
    write_jq_mock
    write_rpm_ostree_mock 'echo "State: booted deployment signed"'
    write_bootc_mock "ghcr.io/projectbluefin/bluefin-lts:stable"
    # image-info.json has a stale placeholder tag
    write_image_info_fixture "bluefin-lts" "stable/testing"

    run_script "${FIXTURE}" "${MOCKDIR}:${PATH}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "bluefin-lts:stable 🔐" ]
}

@test "ublue-image-info: falls back to image-info.json when bootc returns no colon-ref" {
    write_jq_mock
    write_rpm_ostree_mock 'echo "State: booted deployment signed"'
    # bootc mock that returns empty (simulates bootc unavailable or status error)
    write_mock "bootc" '#!/usr/bin/bash
if [[ "$*" == "status --json" ]]; then
    echo "{}"
fi'
    write_image_info_fixture "bluefin" "stable"

    run_script "${FIXTURE}" "${MOCKDIR}:${PATH}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "bluefin:stable 🔐" ]
}

@test "ublue-image-info: falls back to image-info.json when bootc is not installed" {
    write_jq_mock
    write_rpm_ostree_mock 'echo "State: booted deployment signed"'
    # No bootc mock — bootc is not in MOCKDIR
    write_image_info_fixture "bluefin" "latest"

    run_script "${FIXTURE}" "${MOCKDIR}:${PATH}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "bluefin:latest 🔐" ]
}
