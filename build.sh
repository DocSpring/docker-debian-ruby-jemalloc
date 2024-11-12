#!/bin/bash
set -euo pipefail

DEBIAN_VERSION=bookworm
RUBY_VERSION=3.3.6
# Use the SHA256 checksum from ruby-lang.org
RUBY_CHECKSUM="8dc48fffaf270f86f1019053f28e51e4da4cce32a36760a0603a9aee67d7fd8d"
BUNDLER_VERSION=2.5.23

IMAGE_TAG_SUFFIX="$DEBIAN_VERSION-$RUBY_VERSION"

for ARCH in arm64 amd64; do
  IMAGE_TAG="docspringcom/debian-ruby-jemalloc:$ARCH-$IMAGE_TAG_SUFFIX"
  echo "Building $IMAGE_TAG..."

  docker build \
    -t "$IMAGE_TAG" \
    --platform "linux/$ARCH" \
    -f "Dockerfile" \
    --progress=plain \
    --build-arg DEBIAN_VERSION=$DEBIAN_VERSION \
    --build-arg RUBY_VERSION=$RUBY_VERSION \
    --build-arg RUBY_CHECKSUM=$RUBY_CHECKSUM \
    --build-arg BUNDLER_VERSION=$BUNDLER_VERSION \
    .
  docker push "$IMAGE_TAG"
done

docker manifest create --amend docspringcom/debian-ruby-jemalloc:$IMAGE_TAG_SUFFIX \
  docspringcom/debian-ruby-jemalloc:arm64-$IMAGE_TAG_SUFFIX \
  docspringcom/debian-ruby-jemalloc:amd64-$IMAGE_TAG_SUFFIX
docker manifest push docspringcom/debian-ruby-jemalloc:$IMAGE_TAG_SUFFIX

docker manifest create --amend docspringcom/debian-ruby-jemalloc:latest \
  docspringcom/debian-ruby-jemalloc:arm64-$IMAGE_TAG_SUFFIX \
  docspringcom/debian-ruby-jemalloc:amd64-$IMAGE_TAG_SUFFIX
docker manifest push docspringcom/debian-ruby-jemalloc:latest
