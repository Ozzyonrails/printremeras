# syntax=docker/dockerfile:1
# check=error=true
#
# Production image: Rails 8 (Puma behind Thruster) + the built React storefront.
#   docker build -t printremeras .
#   docker run -p 80:80 --env-file .env printremeras
# See docker-compose.yml for the full stack (Postgres + web + worker).

# 3.2 tracks the latest 3.2.x on Debian bookworm. Do not pin 3.2.0 here: that image is
# built on bullseye, whose package repositories are end-of-life and fail apt-get update.
ARG RUBY_VERSION=3.2
ARG NODE_VERSION=20

# ---------- Frontend build (Vite) ----------
FROM docker.io/library/node:${NODE_VERSION}-alpine AS frontend
WORKDIR /app/frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY frontend/ ./
# vite.config.ts writes to ../public/app
RUN npm run build

# ---------- Ruby base ----------
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base
WORKDIR /rails
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# ---------- Gems + app build ----------
FROM base AS build
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libvips libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile
COPY . .
COPY --from=frontend /app/public/app ./public/app
RUN bundle exec bootsnap precompile -j 1 app/ lib/
# Admin CSS through Propshaft; no master key needed.
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# ---------- Runtime ----------
FROM base
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails
RUN mkdir -p /rails/storage /rails/tmp/pids /rails/log && chown -R rails:rails /rails/storage /rails/tmp /rails/log
USER 1000:1000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 80 443
CMD ["./bin/thrust", "./bin/rails", "server"]
