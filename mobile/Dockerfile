# ── Stage 1: Flutter web build ────────────────────────────────────────────────
# Uses the official Flutter git repo — no third-party Docker registry needed.
FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/flutter/bin:${PATH}"
# Render runs Docker rootless — tar can't chown extracted files.
# GNU tar respects this env var and skips ownership changes.
ENV TAR_OPTIONS="--no-same-owner"

# System deps Flutter needs to run on Linux.
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl git unzip xz-utils ca-certificates libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Clone the latest stable Flutter SDK.
# --depth 1 keeps the download small; --branch stable pins to the stable channel.
RUN git clone --depth 1 --branch stable \
        https://github.com/flutter/flutter.git /flutter \
    && flutter precache --web \
    && flutter --version

WORKDIR /app

# Copy dependency files first so Docker can cache the pub-get layer.
# This layer only rebuilds when pubspec.yaml / pubspec.lock actually change.
COPY mobile/pubspec.yaml mobile/pubspec.lock ./
RUN flutter pub get

# Copy the rest of the app source and build.
# --pwa-strategy=none disables the service worker so the browser never serves a
# stale cached app shell — combined with nginx's no-store headers, every visit
# fetches the latest deploy.
COPY mobile/ .
RUN flutter build web --release --pwa-strategy=none

# ── Stage 2: nginx static server ──────────────────────────────────────────────
FROM nginx:alpine

COPY --from=builder /app/build/web /usr/share/nginx/html
COPY mobile/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
