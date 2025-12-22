brew_image := "ghcr.io/ublue-os/brew:latest"

# Build the bluefin-common container locally
build:
    #!/usr/bin/bash
    set -eoux pipefail
    
    brew_image_sha=$(yq -r '.images[] | select(.name == "brew") | .digest' image-versions.yml)
    
    # Verify brew image with cosign
    cosign verify --key https://raw.githubusercontent.com/ublue-os/brew/refs/heads/main/cosign.pub ghcr.io/ublue-os/brew:latest@${brew_image_sha}
    
    podman build \
        --build-arg BREW_IMAGE={{ brew_image }} \
        --build-arg BREW_IMAGE_SHA=${brew_image_sha} \
        -t localhost/bluefin-common:latest \
        -f ./Containerfile .

# Build without cosign verification (for testing)
build-no-verify:
    podman build -t localhost/bluefin-common:latest -f ./Containerfile .

# Inspect the directory structure of an OCI image
tree IMAGE="localhost/bluefin-common:latest":
    echo "FROM alpine:latest" > TreeContainerfile
    echo "RUN apk add --no-cache tree" >> TreeContainerfile
    echo "COPY --from={{IMAGE}} / /mnt/root" >> TreeContainerfile
    echo "CMD tree /mnt/root" >> TreeContainerfile
    podman build -t tree-temp -f TreeContainerfile .
    podman run --rm tree-temp
    rm TreeContainerfile
    podman rmi tree-temp
