#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(sed -nE 's/^version: ([0-9]+\.[0-9]+\.[0-9]+)\+.*/\1/p' "$ROOT_DIR/pubspec.yaml")"
BUNDLE_DIR="$ROOT_DIR/build/linux/x64/release/bundle"
APPIMAGE_DIR="$ROOT_DIR/build/appimage"
APP_DIR="$APPIMAGE_DIR/VNSRB.AppDir"
OUTPUT="$APPIMAGE_DIR/VNSRB-${VERSION}-x86_64.AppImage"
APPIMAGETOOL="${APPIMAGETOOL:-}"

if [[ ! -x "$BUNDLE_DIR/vnsrb" ]]; then
  echo "Linux release bundle not found. Run 'flutter build linux --release' first." >&2
  exit 1
fi

if [[ -z "$APPIMAGETOOL" ]]; then
  if command -v appimagetool >/dev/null 2>&1; then
    APPIMAGETOOL="$(command -v appimagetool)"
  else
    echo "Set APPIMAGETOOL to the official appimagetool executable." >&2
    exit 1
  fi
fi

if [[ ! -x "$APPIMAGETOOL" ]]; then
  echo "APPIMAGETOOL is not executable: $APPIMAGETOOL" >&2
  exit 1
fi

ICON_SOURCE="$ROOT_DIR/android/app/src/main/res/drawable/app_icon.png"
mkdir -p "$APPIMAGE_DIR"
rm -rf "$APP_DIR"
mkdir -p \
  "$APP_DIR/usr/lib/vnsrb" \
  "$APP_DIR/usr/share/icons/hicolor/512x512/apps"
cp -a "$BUNDLE_DIR/." "$APP_DIR/usr/lib/vnsrb/"
install -m 0644 "$ICON_SOURCE" "$APP_DIR/vnsrb.png"
install -m 0644 "$ICON_SOURCE" \
  "$APP_DIR/usr/share/icons/hicolor/512x512/apps/vnsrb.png"

cat > "$APP_DIR/vnsrb.desktop" <<'EOF'
[Desktop Entry]
Name=VNSRB
Comment=Visual novel collection browser powered by VNDB
Exec=AppRun
Icon=vnsrb
Type=Application
Terminal=false
Categories=Game;
StartupWMClass=com.vnpockets.app
EOF

cat > "$APP_DIR/AppRun" <<'EOF'
#!/usr/bin/env bash
set -e
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/lib/vnsrb/vnsrb" "$@"
EOF
chmod 0755 "$APP_DIR/AppRun"

if [[ "$APPIMAGETOOL" == *.AppImage ]]; then
  if [[ -n "${APPIMAGETOOL_RUNTIME_FILE:-}" ]]; then
    "$APPIMAGETOOL" --appimage-extract-and-run \
      --runtime-file "$APPIMAGETOOL_RUNTIME_FILE" "$APP_DIR" "$OUTPUT"
  else
    "$APPIMAGETOOL" --appimage-extract-and-run "$APP_DIR" "$OUTPUT"
  fi
elif [[ -n "${APPIMAGETOOL_RUNTIME_FILE:-}" ]]; then
  "$APPIMAGETOOL" --runtime-file "$APPIMAGETOOL_RUNTIME_FILE" \
    "$APP_DIR" "$OUTPUT"
else
  "$APPIMAGETOOL" "$APP_DIR" "$OUTPUT"
fi

chmod 0755 "$OUTPUT"
echo "Created $OUTPUT"
