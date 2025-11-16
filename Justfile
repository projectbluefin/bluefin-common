# Build the bluefin-common container locally
build:
    buildah build -t bluefin-common:latest -f ./Containerfile .
