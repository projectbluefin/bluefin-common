#!/usr/bin/bash

# shellcheck disable=2046
IMAGE_INFO_FILE="${IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}"

# Prefer live bootc status over image-info.json: the JSON is baked at build
# time and may carry a stale or placeholder image-tag (e.g. "stable/testing"
# on bluefin-lts images built before the tag was wired up as a build arg).
_live_ref=""
if command -v bootc &>/dev/null; then
    _live_ref="$(bootc status --json 2>/dev/null \
        | jq -r '.status.booted.image.image.image // empty' 2>/dev/null)"
fi

if [[ "${_live_ref}" == *:* ]]; then
    _image_name="$(jq -r '."image-name"' < "${IMAGE_INFO_FILE}")"
    echo -n "${_image_name}:${_live_ref##*:}"
else
    echo -n "$(jq -r '"\(.["image-name"]):\(.["image-tag"])"' < "${IMAGE_INFO_FILE}")"
fi

if [[ "$(rpm-ostree status --booted)" =~ "signed" ]]; then
	echo -n " 🔐"
else
	echo -n -e " \033[5m🔓\033[0m"
fi
