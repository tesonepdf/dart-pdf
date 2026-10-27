#!/usr/bin/env bash
# Builds the app for the web with a freshly regenerated bundled render worker.
#
# Consumer apps get the worker from the optional dart_pdf_editor_assets package.
# This repo script rebuilds that asset first so local source changes and deploys
# stay in sync. See doc/render_worker_web.md for the full wiring.
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$APP_DIR/.." && pwd)"

cd "$APP_DIR"

DART="${DART:-fvm dart}"
FLUTTER="${FLUTTER:-fvm flutter}"

echo "==> Regenerating the bundled render worker asset"
$DART run dart_pdf_editor:build_web_worker \
  --out ../packages/dart_pdf_editor_assets/assets/web/pdf_render_worker.dart.js

# Stamp the build with its commit so a `?perf=1` trace says which build it
# came from. Without this a pasted device trace is unattributable by anything
# but timestamps, which has already produced one wrong conclusion (#451).
BUILD_COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
if [ -n "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ]; then
  BUILD_COMMIT="$BUILD_COMMIT-dirty"
fi

BUILD_VERSION="${PDF_BUILD_VERSION:-}"
BUILD_NUMBER="${PDF_BUILD_NUMBER:-}"
if [ -z "$BUILD_VERSION" ] || [ -z "$BUILD_NUMBER" ]; then
  if [ "$(git -C "$REPO_ROOT" rev-parse --is-shallow-repository)" = "true" ]; then
    git -C "$REPO_ROOT" fetch --unshallow origin
  fi

  commit_epoch="$(git -C "$REPO_ROOT" log -1 --format=%ct HEAD)"
  read -r year day hour minute < <(
    TZ=Europe/Rome date -d "@${commit_epoch}" '+%Y %-j %-H %-M'
  )
  BUILD_VERSION="${BUILD_VERSION:-$((year - 2020)).${day}.${hour}${minute}}"
  BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$REPO_ROOT" rev-list --count HEAD)}"
fi

BUILD_ARGS=()
HAS_BUILD_NAME=false
HAS_BUILD_NUMBER=false
for arg in "$@"; do
  case "$arg" in
    --build-name|--build-name=*) HAS_BUILD_NAME=true ;;
    --build-number|--build-number=*) HAS_BUILD_NUMBER=true ;;
  esac
done
if [ "$HAS_BUILD_NAME" = false ]; then
  BUILD_ARGS+=(--build-name="$BUILD_VERSION")
fi
if [ "$HAS_BUILD_NUMBER" = false ]; then
  BUILD_ARGS+=(--build-number="$BUILD_NUMBER")
fi

echo "==> flutter build web $BUILD_VERSION+$BUILD_NUMBER (commit $BUILD_COMMIT) $*"
$FLUTTER build web "${BUILD_ARGS[@]}" \
  --dart-define=PDF_BUILD_COMMIT="$BUILD_COMMIT" "$@"

echo "==> Cache-busting web entrypoints and fonts"
bash "$REPO_ROOT/tool/web_cache_bust.sh" build/web

echo "==> Adding the OCR models (served from this origin for the browser OCR)"
bash "$REPO_ROOT/tool/fetch_ocr_models.sh" build/web

echo "==> Done. build/web includes the dart_pdf_editor_assets worker asset and the OCR models."
