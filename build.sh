#!/bin/bash

PACKAGE_NAME=$(jq -r .name package.json)
VERSION=$(jq -r .version package.json)
GITHUB_USERNAME="raine-works"

if docker buildx ls | grep -q docker-container; then
    echo "Using existing builder."
else
    docker buildx create --name container --driver=docker-container
fi

docker buildx build \
    -f ./Dockerfile \
    --platform linux/amd64,linux/arm64 \
    -t ghcr.io/${GITHUB_USERNAME}/${PACKAGE_NAME}:latest \
    -t ghcr.io/${GITHUB_USERNAME}/${PACKAGE_NAME}:${VERSION} \
    --builder=container \
    --push \
    .
