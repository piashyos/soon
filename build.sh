#!/bin/sh
# Usage: ./build.sh            -> build/Soon.app
#        ./build.sh install    -> also copy to /Applications and launch
set -eu
cd "$(dirname "$0")"

swift build -c release
APP=build/Soon.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Soon "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp AppIcon.icns "$APP/Contents/Resources/"  # regenerate with: swift icon.swift

# A stable identity keeps the Calendar permission across rebuilds; ad-hoc ("-") re-prompts.
SIGN_ID=${SIGN_ID:-$(security find-identity -v -p codesigning | awk '/Apple Development/ {print $2; exit}')}
codesign --force --sign "${SIGN_ID:--}" "$APP"
echo "Built $APP (signed with ${SIGN_ID:--})"

if [ "${1:-}" = install ]; then
  pkill -x Soon || true
  rm -rf /Applications/Soon.app
  cp -R "$APP" /Applications/
  open /Applications/Soon.app
fi
