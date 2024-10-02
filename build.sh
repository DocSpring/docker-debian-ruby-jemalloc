#!/bin/bash
set -euo pipefail

DEBIAN_VERSION=bookworm
RUBY_VERSION=3.3.5
RUBY_CHECKSUM="3781a3504222c2f26cb4b9eb9c1a12dbf4944d366ce24a9ff8cf99ecbce75196"
BUNDLER_VERSION=2.5.20

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
