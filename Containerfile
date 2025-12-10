FROM docker.io/library/alpine:latest AS build

COPY --from=ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest / /tmp

RUN sh <<EOF
set -xeuo pipefail
mkdir -p /out/bluefin/usr/share/backgrounds /out/bluefin/usr/share/gnome-background-properties

find /tmp -maxdepth 1 -type f -name "[0-9][0-9]-bluefin-*.jxl" \
  -exec cp {} /out/bluefin/usr/share/backgrounds/ \;

find /tmp -maxdepth 1 -type f -name "[0-9][0-9]-bluefin.xml" \
  -exec cp {} /out/bluefin/usr/share/backgrounds/ \;

find /tmp/gnome-background-properties/ -maxdepth 1 -type f -name "[0-9][0-9]-bluefin.xml" \
  -exec cp {} /out/bluefin/usr/share/gnome-background-properties \;

find /tmp -maxdepth 1 -type f -name "xe_*.jxl" \
  -exec cp {} /out/bluefin/usr/share/backgrounds/ \;

find /tmp/gnome-background-properties/ -maxdepth 1 -type f -name "xe_*.xml" \
  -exec cp {} /out/bluefin/usr/share/gnome-background-properties \;
EOF

RUN apk add just

RUN install -d /out/shared/usr/share/bash-completion/completions /out/shared/usr/share/zsh/site-functions /out/shared/usr/share/fish/vendor_completions.d/ && \
  just --completions bash | sed -E 's/([\(_" ])just/\1ujust/g' > /out/shared/usr/share/bash-completion/completions/ujust && \
  just --completions zsh | sed -E 's/([\(_" ])just/\1ujust/g' > /out/shared/usr/share/zsh/site-functions/_ujust && \
  just --completions fish | sed -E 's/([\(_" ])just/\1ujust/g' > /out/shared/usr/share/fish/vendor_completions.d/ujust.fish

FROM scratch AS ctx
COPY /system_files/shared /system_files/shared/
COPY /system_files/bluefin /system_files/bluefin

COPY --from=build /out/shared /system_files/shared
COPY --from=build /out/bluefin /system_files/bluefin
