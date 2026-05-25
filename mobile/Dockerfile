# ── Stage 1: Flutter web build ────────────────────────────────────────────────
# Builds the Flutter web app inside Docker so the server only needs Docker+Git.
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# Copy dependency manifests first — lets Docker cache the pub get layer
# and skip it on rebuilds where only Dart source files changed.
COPY mobile/pubspec.yaml mobile/pubspec.lock ./
RUN flutter pub get

# Copy the rest of the app source.
COPY mobile/ .

RUN flutter build web --release

# ── Stage 2: nginx static server ──────────────────────────────────────────────
FROM nginx:alpine

COPY --from=builder /app/build/web /usr/share/nginx/html
COPY mobile/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
