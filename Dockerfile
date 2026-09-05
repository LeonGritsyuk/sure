# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=3.4.9
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim AS base

# Predefined proxy ARGs (http_proxy/https_proxy/no_proxy and uppercase) are
# forwarded automatically by BuildKit, but declared here so ENV can export
# them for tools (bundler, npm) that only read the process environment.
ARG http_proxy
ARG https_proxy
ARG no_proxy
ENV http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    HTTP_PROXY=${http_proxy} \
    HTTPS_PROXY=${https_proxy} \
    no_proxy=${no_proxy} \
    NO_PROXY=${no_proxy}

# Rails app lives here
WORKDIR /rails

# Install base packages
# poppler-utils provides pdftoppm, required for the PDF vision processing path
# Retries/timeouts absorb transient proxy drops seen on flaky corporate networks.
RUN echo 'Acquire::Retries "5"; Acquire::http::Timeout "30"; Acquire::https::Timeout "30";' > /etc/apt/apt.conf.d/80-retries \
    && apt-get update -qq \
    && apt-get install --no-install-recommends -y curl libvips postgresql-client libyaml-0-2 procps libjemalloc2 poppler-utils \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment
ARG BUILD_COMMIT_SHA
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    BUILD_COMMIT_SHA=${BUILD_COMMIT_SHA}

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq \
    && apt-get install --no-install-recommends -y build-essential libpq-dev git pkg-config libyaml-dev \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY .ruby-version Gemfile Gemfile.lock ./
RUN bundle install \
    && rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git \
    && bundle exec bootsnap precompile --gemfile -j 0

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile -j 0 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Final stage for app image
FROM base

# Build-time proxy only: clear it so the running app's own outbound calls
# (bank sync, OpenAI, exchange rate providers) aren't silently routed through it.
ENV http_proxy="" \
    https_proxy="" \
    HTTP_PROXY="" \
    HTTPS_PROXY="" \
    no_proxy="" \
    NO_PROXY=""

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# tmp/sockets has no .keep (see .dockerignore) so it never reaches the build
# context; create it explicitly so Puma can write to it as the rails user.
# chmod (not just chown) because some pre-existing dirs (tmp/pids, tmp/storage)
# are copied in from the host build context missing the owner write bit
# (observed with Docker Desktop's Windows file sharing) -- chown alone doesn't
# fix that, so ActiveStorage/Puma get EACCES on an otherwise correctly-owned dir.
RUN mkdir -p tmp/pids tmp/cache tmp/sockets tmp/storage log storage \
    && chown -R rails:rails tmp log storage \
    && chmod -R u+rwX tmp log storage
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/rails", "server"]
