# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=3.4.7
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim-trixie AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libvips postgresql-client libyaml-0-2

# Set production environment
ARG BUILD_COMMIT_SHA
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    BUILD_COMMIT_SHA=${BUILD_COMMIT_SHA}
    
# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get install --no-install-recommends -y build-essential libpq-dev git pkg-config libyaml-dev

# Install application gems
COPY .ruby-version Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile -j 0

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile -j 0 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Clean up build artifacts BEFORE copying to final stage (reduces final image size)
RUN rm -rf /rails/tmp/cache \
    /rails/tmp/*.pid \
    /rails/spec \
    /rails/test \
    /rails/doc \
    /rails/docs \
    /rails/.git \
    /rails/*.md \
    /rails/CONTRIBUTING.md \
    /rails/CHANGES.md \
    /rails/CLAUDE.md \
    /rails/.github \
    /rails/.vscode \
    /rails/.idea \
    /rails/.devcontainer \
    /rails/Dockerfile* \
    /rails/.dockerignore \
    /rails/compose*.yml \
    /rails/Makefile \
    /rails/perf.rake \
    /rails/LICENSE \
    /rails/Procfile.dev \
    /rails/package-lock.json && \
    find "${BUNDLE_PATH}"/ruby/*/gems -maxdepth 2 -type d \( -name test -o -name spec -o -name docs -o -name doc -o -name examples -o -name sample \) | xargs rm -rf && \
    find "${BUNDLE_PATH}"/ruby/*/gems -type f \( -name '*.md' -o -name 'README*' -o -name 'CHANGELOG*' -o -name 'LICENSE*' -o -name 'COPYING*' \) -delete && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/gems/rdoc-*

# Final stage for app image
FROM base

# Clean up installation packages to reduce image size
RUN rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy built artifacts: gems, application (already cleaned in build stage)
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/rails", "server"]
