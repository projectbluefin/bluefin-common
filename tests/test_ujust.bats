#!/usr/bin/env bats
# Tests for the ujust wrapper's on-demand fzf installation.

UJUST="$BATS_TEST_DIRNAME/../system_files/shared/usr/bin/ujust"
WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin"
    : > "${WORKDIR}/calls.log"

    cat > "${WORKDIR}/bin/brew" <<'EOF'
#!/usr/bin/bash
printf 'brew %s\n' "$*" >> "${CALLS}"
if [[ "$1" == shellenv ]]; then
    printf 'export PATH="%s:$PATH"\n' "${MOCK_BIN}"
fi
EOF

    cat > "${WORKDIR}/bin/just" <<'EOF'
#!/usr/bin/bash
printf 'just %s\n' "$*" >> "${CALLS}"
EOF

    chmod +x "${WORKDIR}/bin/brew" "${WORKDIR}/bin/just"
}

teardown() {
    rm -rf "${WORKDIR}"
}

@test "ujust installs fzf before --choose when fzf is missing" {
    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" \
        CALLS="${WORKDIR}/calls.log" MOCK_BIN="${WORKDIR}/bin" \
        bash "${UJUST}" --choose

    [ "${status}" -eq 0 ]
    grep -qF "brew install fzf" "${WORKDIR}/calls.log"
    grep -qF "brew shellenv" "${WORKDIR}/calls.log"
    grep -qF "just --justfile /usr/share/ublue-os/just/00-entry.just --choose" "${WORKDIR}/calls.log"
}

@test "ujust does not install fzf for other commands" {
    run env PATH="${WORKDIR}/bin:/usr/bin:/bin" \
        CALLS="${WORKDIR}/calls.log" MOCK_BIN="${WORKDIR}/bin" \
        bash "${UJUST}" --list

    [ "${status}" -eq 0 ]
    ! grep -qF "brew install fzf" "${WORKDIR}/calls.log"
    grep -qF "just --justfile /usr/share/ublue-os/just/00-entry.just --list" "${WORKDIR}/calls.log"
}
