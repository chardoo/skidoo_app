# ── Build ────────────────────────────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS builder
WORKDIR /app
COPY mobile/ .
RUN flutter config --enable-web
RUN flutter pub get
RUN flutter build web --release

# ── Serve ────────────────────────────────────────────────────────────────────
FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
COPY mobile/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
