#!/bin/sh
# Usage: ./build.sh            -> build/Soon.app (universal: Apple Silicon + Intel)
#        ./build.sh install    -> also copy to /Applications and launch
#        ./build.sh dmg        -> also build/Soon-<version>.dmg for a GitHub release
set -eu
cd "$(dirname "$0")"

ARCHS="--arch arm64 --arch x86_64"
swift build -c release $ARCHS
BIN="$(swift build -c release $ARCHS --show-bin-path)/Soon"
APP=build/Soon.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp AppIcon.icns "$APP/Contents/Resources/"  # regenerate with: swift icon.swift

# A stable identity keeps the Calendar permission across rebuilds; ad-hoc ("-") re-prompts.
SIGN_ID=${SIGN_ID:-$(security find-identity -v -p codesigning | awk '/Apple Development/ {print $2; exit}')}
codesign --force --sign "${SIGN_ID:--}" "$APP"
echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/Soon"), signed with ${SIGN_ID:--})"

case "${1:-}" in
install)
  pkill -x Soon || true
  rm -rf /Applications/Soon.app
  cp -R "$APP" /Applications/
  open /Applications/Soon.app
  ;;
dmg)
  VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
  STAGE=build/dmg
  rm -rf "$STAGE"
  mkdir -p "$STAGE"
  ditto "$APP" "$STAGE/Soon.app"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname Soon -srcfolder "$STAGE" -format UDZO -ov "build/Soon-$VERSION.dmg" >/dev/null
  rm -rf "$STAGE"
  echo "Built build/Soon-$VERSION.dmg"
  ;;
esac
