#!/usr/bin/env bash
set -euo pipefail

case "${API_BASE_URL:-}" in
  https://*/api/v1) ;;
  *) printf '%s\n' 'API_BASE_URL debe apuntar a una API HTTPS /api/v1.' >&2; exit 1 ;;
esac
case "$API_BASE_URL" in
  *\?*|*\#*|*\@*) printf '%s\n' 'API_BASE_URL contiene componentes no permitidos.' >&2; exit 1 ;;
esac

sdk_dir="$(mktemp -d)"
trap 'rm -rf -- "$sdk_dir"' EXIT
git clone --depth 1 --branch 3.41.9 https://github.com/flutter/flutter.git "$sdk_dir/flutter"
revision="$(git -C "$sdk_dir/flutter" rev-parse HEAD)"
case "$revision" in
  00b0c91f06*) ;;
  *) printf '%s\n' 'La revisión Flutter 3.41.9 no coincide con la aprobada.' >&2; exit 1 ;;
esac
"$sdk_dir/flutter/bin/flutter" pub get --enforce-lockfile
"$sdk_dir/flutter/bin/flutter" build web --release --no-pub --dart-define="API_BASE_URL=$API_BASE_URL"
