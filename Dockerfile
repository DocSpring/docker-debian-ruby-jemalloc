ARG DEBIAN_VERSION=unset
FROM debian:${DEBIAN_VERSION}-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG RUBY_VERSION
ARG RUBY_CHECKSUM
ARG BUNDLER_VERSION

# MALLOC_CONF for Ruby with jemalloc 5 (not 3)
# See: https://gist.github.com/jjb/9ff0d3f622c8bbe904fe7a82e35152fc

ENV DEBIAN_FRONTEND=noninteractive \
    USER="root" \
    PATH="/usr/local/bundle/bin/:/usr/local/bundle/gems/bin:$PATH" \
    LANGUAGE="C.UTF-8 LANG=C.UTF-8 LC_ALL=C.UTF-8" \
    RUBY_VERSION="$RUBY_VERSION" \
    GEM_HOME="/usr/local/bundle" \
    GEM_PATH="/usr/local/bundle" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_BIN="/usr/local/bundle/bin" \
    BUNDLE_SILENCE_ROOT_WARNING="1" \
    BUNDLE_APP_CONFIG="/usr/local/bundle" \
    RUBY_PATH="/usr/local/bin" \
    MALLOC_CONF='dirty_decay_ms:0,muzzy_decay_ms:0,narenas:2,background_thread:true,thp:never' 

# Set up minimal .bashrc and .gemrc
RUN echo "Arch: $(uname -m)" \
  && echo 'export LS_OPTIONS="--color=auto"\
  \nalias ls="ls $LS_OPTIONS"\
  \nalias ll="ls $LS_OPTIONS -l"\
  \nalias l="ls $LS_OPTIONS -lA"' >> "$HOME/.bashrc" \
  && echo "gem: --no-document" > "$HOME/.gemrc"

RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y -q --no-install-recommends \
    curl \
    ca-certificates \
    build-essential \
    bison \
    libyaml-dev \
    libgdbm-dev \
    libreadline-dev \
    libjemalloc-dev \
    libncurses5-dev \
    libffi-dev \
    zlib1g-dev \
    libssl-dev \
  && mkdir -p /tmp/build \
  && cd /tmp/build \
  && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain=1.77.0 \
  && curl -L -o "ruby-${RUBY_VERSION}.tar.gz" "https://cache.ruby-lang.org/pub/ruby/${RUBY_VERSION%.*}/ruby-${RUBY_VERSION}.tar.gz" \
  && sha256sum "ruby-${RUBY_VERSION}.tar.gz" \
  && echo "${RUBY_CHECKSUM}  ruby-${RUBY_VERSION}.tar.gz" | sha256sum --strict -c - \
  && tar xf "ruby-${RUBY_VERSION}.tar.gz" \
  && source "${HOME}/.cargo/env" \
  && cd "ruby-${RUBY_VERSION}" \
  && ./configure --with-jemalloc --enable-shared --disable-install-doc "${ADDITIONAL_FLAGS}" \
  && make -j"$(nproc)" > /dev/null \
  && make install \
  && ruby --version \
  && rustup self uninstall -y \
  && rm -rf /tmp/build \
  && apt-get remove -y --purge \
    curl ca-certificates build-essential bison libyaml-dev libgdbm-dev libreadline-dev libjemalloc-dev \
    libncurses5-dev libffi-dev zlib1g-dev libssl-dev \
  && apt-get autoremove --assume-yes \
  && apt-get install -y -q --no-install-recommends \
    libjemalloc2 \
    libyaml-0-2 \
    libssl3 \
    libffi8 \
    libncurses6 \
    libgdbm6 \
    libreadline8 \
    zlib1g \
  && rm -rf /var/lib/apt/lists/*

# Run some tests for ruby + jemalloc and update Rubygems and bundler
RUN which ruby \
  && if ! ruby --version | grep "$RUBY_VERSION"; then \
    echo "Ruby version did not include '$RUBY_VERSION'!" \
    && exit 1; \
  fi \
  && RB_CONFIG_LIBS="$(ruby -r rbconfig -e "puts ['LIBS', 'SOLIBS'].map { |k| RbConfig::CONFIG[k] }.join")" \
  && printf "Checking RbConfig LIBS and SOLIBS for jemalloc: " \
  && echo $RB_CONFIG_LIBS \
  && if ! echo $RB_CONFIG_LIBS | grep -q jemalloc; then \
    echo "Ruby was not compiled with jemalloc!" \
    && exit 1; \
  fi \
  && printf "Checking for YJIT: " \
  && if ! RUBY_YJIT_ENABLE=1 ruby --version | grep "YJIT"; then \
    echo "Ruby was not compiled with YJIT!" \
    && exit 1; \
  fi \
  && printf "Checking Ruby evaluation: " \
  && ruby -e 'a = 3 + 4; puts "Test: #{a}"' | grep "Test: 7" \
  && printf "Checking libyaml version: " \
  && ruby -e 'require "yaml"; puts Psych.libyaml_version.join(".")' | grep "0.2" \
  && mkdir -p "/usr/local/bundle" \
  && echo "Updating Rubygems..." \
  && gem update --system | tail -n 1 \
  && echo "Installing Bundler $BUNDLER_VERSION..." \
  && gem install bundler --version "$BUNDLER_VERSION" --force \
  && bundle --version
