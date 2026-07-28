#!/usr/bin/env bats
# Tests for system_files/shared/usr/bin/ujust
#
# Covers the fzf → gum-filter chooser fallback added to fix:
#   https://github.com/projectbluefin/common/issues/861
#
# Run: bats tests/test_ujust.bats

bats_require_minimum_version 1.5.0

UJUST="${BATS_TEST_DIRNAME}/../system_files/shared/usr/bin/ujust"

WORKDIR=""

setup() {
    WORKDIR="$(mktemp -d)"
    mkdir -p "${WORKDIR}/bin"

    # Stub just — records JUST_CHOOSER and argv to a log, then exits 0
    cat > "${WORKDIR}/bin/just" << 'EOF'
#!/bin/sh
echo "JUST_CHOOSER=${JUST_CHOOSER}" >> "${WORKDIR}/just.log"
echo "argv=$*" >> "${WORKDIR}/just.log"
EOF
    # WORKDIR is not expanded inside heredoc; write it via printf instead
    printf '#!/bin/sh\necho "JUST_CHOOSER=${JUST_CHOOSER}" >> "%s/just.log"\necho "argv=$*" >> "%s/just.log"\n' \
        "${WORKDIR}" "${WORKDIR}" > "${WORKDIR}/bin/just"
    chmod +x "${WORKDIR}/bin/just"

    export PATH="${WORKDIR}/bin:${PATH}"
}

teardown() {
    rm -rf "${WORKDIR}"
}

# ---------------------------------------------------------------------------
# Chooser fallback: fzf absent, gum present → use gum filter
# ---------------------------------------------------------------------------

@test "ujust: sets JUST_CHOOSER=gum filter --no-limit when fzf absent and gum present" {
    # Provide gum stub but NO fzf
    printf '#!/bin/sh\n' > "${WORKDIR}/bin/gum"
    chmod +x "${WORKDIR}/bin/gum"

    run bash "${UJUST}"
    [ "${status}" -eq 0 ]
    grep -q 'JUST_CHOOSER=gum filter --no-limit' "${WORKDIR}/just.log"
}

# ---------------------------------------------------------------------------
# Chooser passthrough: fzf present → do not override JUST_CHOOSER
# ---------------------------------------------------------------------------

@test "ujust: does not set JUST_CHOOSER when fzf is present" {
    # Provide both fzf and gum stubs
    printf '#!/bin/sh\n' > "${WORKDIR}/bin/fzf"
    chmod +x "${WORKDIR}/bin/fzf"
    printf '#!/bin/sh\n' > "${WORKDIR}/bin/gum"
    chmod +x "${WORKDIR}/bin/gum"

    run bash "${UJUST}"
    [ "${status}" -eq 0 ]
    # JUST_CHOOSER must be empty (not overridden)
    grep -q 'JUST_CHOOSER=$' "${WORKDIR}/just.log"
}

# ---------------------------------------------------------------------------
# Neither fzf nor gum: do not crash ujust itself, let just handle it
# ---------------------------------------------------------------------------

@test "ujust: does not set JUST_CHOOSER when neither fzf nor gum is present" {
    # No fzf, no gum — ujust should still invoke just without modifying the env
    run bash "${UJUST}"
    [ "${status}" -eq 0 ]
    grep -q 'JUST_CHOOSER=$' "${WORKDIR}/just.log"
}

# ---------------------------------------------------------------------------
# Argument passthrough
# ---------------------------------------------------------------------------

@test "ujust: passes arguments through to just" {
    run bash "${UJUST}" --list
    [ "${status}" -eq 0 ]
    grep -q 'argv=.*--list' "${WORKDIR}/just.log"
}
