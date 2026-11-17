#!/usr/bin/env bash
set -e

# ==============================================================================
# Hopy - Dual Export & Packaging Script (Web + Android)
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUILD_DIR="$ROOT_DIR/build"
WEB_BUILD_DIR="$BUILD_DIR/web"
ANDROID_BUILD_DIR="$BUILD_DIR/android"
WEB_ZIP="$BUILD_DIR/Hopy-Web.zip"
ANDROID_APK="$ANDROID_BUILD_DIR/Hopy.apk"

echo "=========================================="
echo "   HOPY: DUAL EXPORT (WEB + ANDROID)     "
echo "=========================================="

mkdir -p "$WEB_BUILD_DIR"
mkdir -p "$ANDROID_BUILD_DIR"

# 1. Run Godot Test Suites
echo "--> Running headless verification tests..."
for t in tests/Test*.tscn; do
    godot --headless "$t" >/dev/null 2>&1 || {
        echo "❌ Test $t failed! Aborting export."
        exit 1
    }
done
echo "✅ All 9 test suites passed!"

# 2. Export Web (HTML5 / PWA)
echo "--> Exporting Web (Release)..."
godot --headless --export-release "Web" "$WEB_BUILD_DIR/index.html"
(cd "$WEB_BUILD_DIR" && zip -q -r "$WEB_ZIP" ./*)
echo "✅ Web build complete: $WEB_ZIP ($(du -h "$WEB_ZIP" | cut -f1))"

# 3. Export Android (APK)
echo "--> Exporting Android (Release)..."
godot --headless --export-release "Android" "$ANDROID_APK"
echo "✅ Android build complete: $ANDROID_APK ($(du -h "$ANDROID_APK" | cut -f1))"

# 4. Summary
echo ""
echo "=========================================="
echo "   BUILD ARTIFACTS READY FOR UPLOAD       "
echo "=========================================="
echo " 🌐 Web (HTML5/PWA):  $WEB_ZIP"
echo " 📱 Android (APK):    $ANDROID_APK"
echo "=========================================="

# 5. Optional Itch.io upload via butler
if command -v butler >/dev/null 2>&1 && [ -f "$HOME/.config/itch/butler_creds" ]; then
    if [ -n "$ITCH_TARGET" ]; then
        echo "--> Uploading to Itch.io ($ITCH_TARGET)..."
        butler push "$WEB_BUILD_DIR" "$ITCH_TARGET:html5"
        butler push "$ANDROID_APK" "$ITCH_TARGET:android"
        echo "✅ Uploaded to itch.io channels :html5 and :android simultaneously!"
    else
        echo "ℹ️  To upload to Itch.io automatically, set ITCH_TARGET (e.g. ITCH_TARGET=username/hopy ./scripts/build_all.sh)"
    fi
fi
