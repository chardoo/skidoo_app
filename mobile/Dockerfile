# ── Build ────────────────────────────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS builder
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=false

# ── Serve ────────────────────────────────────────────────────────────────────
FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
