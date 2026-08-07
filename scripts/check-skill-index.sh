#!/usr/bin/env bash
# Verify docs/SKILL.md task table links to every docs/skills/*.md file
# (flat pages) and every docs/skills/*/SKILL.md file (per-skill directories).
set -euo pipefail

SKILL_INDEX="docs/SKILL.md"
rc=0

shopt -s nullglob
for f in docs/skills/*.md; do
    base=$(basename "$f")
    if ! grep -qE "\[.*\]\(skills/${base}\)" "${SKILL_INDEX}"; then
        echo "error: ${SKILL_INDEX} is missing a link to skills/${base}"
        rc=1
    fi
done

for f in docs/skills/*/SKILL.md; do
    rel="${f#docs/}"
    if ! grep -qE "\[.*\]\(${rel}\)" "${SKILL_INDEX}"; then
        echo "error: ${SKILL_INDEX} is missing a link to ${rel}"
        rc=1
    fi
done
shopt -u nullglob

exit $rc
