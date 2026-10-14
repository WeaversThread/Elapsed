#!/bin/bash
# Usage: bash build.sh [--install] [--zip]
#   --install  quit Elapsed, replace /Applications/Elapsed.app, relaunch
#   --zip      also write build/Elapsed-<version>.zip for a release
set -e

cd "$(dirname "$0")"

INSTALL=0
ZIP=0
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=1 ;;
        --zip)     ZIP=1 ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

# Command Line Tools 27 don't ship the SwiftUI macro plugin the macOS 27 SDK needs
# (@State fails with "SwiftUIMacros.StateMacro could not be found"), so build
# against the 26 SDK when only the CLT are installed.
if [ -z "$SDKROOT" ]; then
    DEV_DIR="$(xcode-select -p 2>/dev/null || true)"
    if [[ "$DEV_DIR" == *CommandLineTools* ]]; then
        for sdk in "$DEV_DIR/SDKs/MacOSX26.5.sdk" "$DEV_DIR/SDKs/MacOSX26.sdk"; do
            if [ -d "$sdk" ]; then
                export SDKROOT="$sdk"
                break
            fi
        done
    fi
fi

echo "Building Elapsed..."
swift build -c release

APP="build/Elapsed.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/Elapsed "$APP/Contents/MacOS/Elapsed"
cp -r .build/release/Elapsed_Elapsed.bundle "$APP/Contents/Resources/"
cp StatusTimer/Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp StatusTimer/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature: no developer account needed, but Gatekeeper still treats it as unsigned.
codesign --force --deep -s - "$APP"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" StatusTimer/Info.plist)
echo "Built: $APP ($VERSION)"

if [ "$ZIP" = 1 ]; then
    ZIPFILE="build/Elapsed-$VERSION.zip"
    rm -f "$ZIPFILE"
    ditto -c -k --keepParent "$APP" "$ZIPFILE"
    echo "Zipped: $ZIPFILE"
fi

if [ "$INSTALL" = 1 ]; then
    osascript -e 'quit app "Elapsed"' 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -x Elapsed >/dev/null || break
        sleep 0.3
    done
    pkill -x Elapsed 2>/dev/null || true
    rm -rf /Applications/Elapsed.app
    ditto "$APP" /Applications/Elapsed.app
    # Register the elapsed:// URL scheme with Launch Services.
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Elapsed.app
    open /Applications/Elapsed.app
    echo "Installed and launched /Applications/Elapsed.app"
else
    echo ""
    echo "To install: bash build.sh --install"
fi
