#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
APP_NAME="AppAttestDecoder"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
case "$MODE" in run|--debug|--logs|--verify|--build|--install|--package) ;; *) echo "Usage: $0 [--build|--install|--package|--verify|--debug|--logs]" >&2; exit 2;; esac
./script/check_environment.sh
CONFIGURATION="${BUILD_CONFIGURATION:-debug}"
case "$MODE" in --install|--package) CONFIGURATION=release;; esac
case "$CONFIGURATION" in debug|release) ;; *) echo "BUILD_CONFIGURATION must be debug or release" >&2; exit 2;; esac
if [[ "$MODE" != "--build" && "$MODE" != "--package" ]]; then pkill -x "$APP_NAME" >/dev/null 2>&1 || true; fi
swift build -c "$CONFIGURATION"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
APP_BUNDLE="$ROOT_DIR/dist/App Attest Decoder.app"
if [[ -e "$APP_BUNDLE" ]]; then rm -rf "$APP_BUNDLE"; fi
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
for resource in "$BIN_DIR"/*.bundle; do
  [[ ! -d "$resource" ]] || ditto "$resource" "$APP_BUNDLE/Contents/Resources/$(basename "$resource")"
done
cp Sources/AppAttestDecoder/Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>AppAttestDecoder</string>
<key>CFBundleIdentifier</key><string>com.local.appattestdecoder</string>
<key>CFBundleName</key><string>App Attest Decoder</string>
<key>CFBundleDisplayName</key><string>App Attest Decoder</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>Copyright © 2026 Shankar Madeshvaran. MIT License.</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
case "$MODE" in
--build) echo "Built $APP_BUNDLE" ;;
--package)
  ARCH="$(uname -m)"
  ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ROOT_DIR/dist/AppAttestDecoder-macos-$ARCH.zip"
  (cd "$ROOT_DIR/dist" && shasum -a 256 "AppAttestDecoder-macos-$ARCH.zip" > "AppAttestDecoder-macos-$ARCH.zip.sha256")
  echo "Packaged dist/AppAttestDecoder-macos-$ARCH.zip (local signing; not notarized)"
  ;;
--install)
  INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
  DESTINATION="$INSTALL_DIR/App Attest Decoder.app"
  mkdir -p "$INSTALL_DIR"
  if [[ -e "$DESTINATION" ]]; then
    EXISTING_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DESTINATION/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "$EXISTING_ID" != com.local.appattestdecoder ]]; then
      echo "Refusing to replace an unrelated app at $DESTINATION" >&2; exit 1
    fi
    rm -rf "$DESTINATION"
  fi
  ditto "$APP_BUNDLE" "$DESTINATION"
  echo "Installed $DESTINATION"
  if [[ "${OPEN_AFTER_INSTALL:-1}" == 1 ]]; then /usr/bin/open "$DESTINATION"; fi
  ;;
--debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
--logs) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "AppAttestDecoder"' ;;
--verify) /usr/bin/open -n "$APP_BUNDLE"; sleep 2; pgrep -x "$APP_NAME" >/dev/null ;;
run) /usr/bin/open -n "$APP_BUNDLE" ;;
esac
