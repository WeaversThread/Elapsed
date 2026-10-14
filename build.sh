#!/bin/bash
# Usage: bash build.sh [--test | --install | --release | --appstore]
#
#   (nothing)   build build/Elapsed.app for this Mac, ad-hoc signed
#   --test      run the tests instead of building the app
#   --install   build, quit Elapsed, replace /Applications/Elapsed.app, relaunch
#
#   --release   for the web: a universal app (Apple silicon + Intel) as
#               build/Elapsed-<version>.dmg and .zip.
#               With a "Developer ID Application" certificate in the keychain it is signed
#               with it and notarized, using credentials saved once with:
#                   xcrun notarytool store-credentials elapsed-notary
#               Without one it is ad-hoc signed, and people open it with right-click › Open.
#
#   --appstore  for the Mac App Store: a universal, sandboxed app packaged as
#               build/Elapsed-<version>.pkg, to upload with Apple's Transporter app.
#               Needs an "Apple Distribution" (or "3rd Party Mac Developer Application")
#               certificate, a "3rd Party Mac Developer Installer" (or "Mac Installer
#               Distribution") certificate, and the app's Mac App Store provisioning profile
#               saved as Elapsed.provisionprofile next to this script.
set -e

cd "$(dirname "$0")"

MODE=build
for arg in "$@"; do
    case "$arg" in
        --test)     MODE=test ;;
        --install)  MODE=install ;;
        --release)  MODE=release ;;
        --appstore) MODE=appstore ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

# Command Line Tools 27 don't ship the SwiftUI macro plugin the macOS 27 SDK needs
# (@State fails with "SwiftUIMacros.StateMacro could not be found"), so build
# against the 26 SDK when only the CLT are installed.
DEV_DIR="$(xcode-select -p 2>/dev/null || true)"
if [ -z "$SDKROOT" ] && [[ "$DEV_DIR" == *CommandLineTools* ]]; then
    for sdk in "$DEV_DIR/SDKs/MacOSX26.5.sdk" "$DEV_DIR/SDKs/MacOSX26.sdk"; do
        if [ -d "$sdk" ]; then
            export SDKROOT="$sdk"
            break
        fi
    done
fi

if [ "$MODE" = test ]; then
    # The CLT keep the Swift Testing macro plugin in a folder SwiftPM doesn't search.
    TESTING_PLUGINS="$DEV_DIR/usr/lib/swift/host/plugins/testing"
    if [ -d "$TESTING_PLUGINS" ]; then
        swift test -Xswiftc -plugin-path -Xswiftc "$TESTING_PLUGINS"
    else
        swift test
    fi
    exit
fi

APP="build/Elapsed.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" StatusTimer/Info.plist)
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" StatusTimer/Info.plist)
mkdir -p build

identity() {
    security find-identity -v -p codesigning 2>/dev/null | grep -o "\"$1[^\"]*\"" | head -1 | tr -d '"'
}

# The App Store needs certificates and a profile; check before spending time compiling.
if [ "$MODE" = appstore ]; then
    APP_ID=$(identity "Apple Distribution")
    [ -z "$APP_ID" ] && APP_ID=$(identity "3rd Party Mac Developer Application")
    PKG_ID=$(identity "3rd Party Mac Developer Installer")
    [ -z "$PKG_ID" ] && PKG_ID=$(identity "Mac Installer Distribution")
    PROFILE="Elapsed.provisionprofile"
    MISSING=""
    [ -z "$APP_ID" ] && MISSING="$MISSING\n  - an \"Apple Distribution\" certificate"
    [ -z "$PKG_ID" ] && MISSING="$MISSING\n  - a \"Mac Installer Distribution\" certificate"
    [ ! -f "$PROFILE" ] && MISSING="$MISSING\n  - the Mac App Store provisioning profile, saved as $PROFILE"
    if [ -n "$MISSING" ]; then
        echo -e "Can't build for the App Store yet. Missing:$MISSING"
        echo "All three come from developer.apple.com (Certificates, IDs & Profiles) with a paid"
        echo "Apple Developer account; register the bundle ID com.endurance.Elapsed there first."
        exit 1
    fi
fi

# MARK: - Compile

echo "Building Elapsed $VERSION ($BUILD)..."
if [ "$MODE" = release ] || [ "$MODE" = appstore ]; then
    # Universal: one slice per architecture, joined with lipo.
    swift build -c release --triple arm64-apple-macosx15.0
    cp "$(swift build -c release --triple arm64-apple-macosx15.0 --show-bin-path)/Elapsed" build/Elapsed-arm64
    swift build -c release --triple x86_64-apple-macosx15.0
    cp "$(swift build -c release --triple x86_64-apple-macosx15.0 --show-bin-path)/Elapsed" build/Elapsed-x86_64
    lipo -create build/Elapsed-arm64 build/Elapsed-x86_64 -output build/Elapsed-bin
    rm build/Elapsed-arm64 build/Elapsed-x86_64
else
    swift build -c release
    cp "$(swift build -c release --show-bin-path)/Elapsed" build/Elapsed-bin
fi

# MARK: - Assemble

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv build/Elapsed-bin "$APP/Contents/MacOS/Elapsed"
cp StatusTimer/Resources/AppIcon.icns StatusTimer/Resources/alarm.mp3 "$APP/Contents/Resources/"
cp StatusTimer/Info.plist "$APP/Contents/Info.plist"

make_dmg() {
    local dmg="build/Elapsed-$VERSION.dmg"
    rm -rf build/dmg "$dmg"
    mkdir -p build/dmg
    ditto "$APP" build/dmg/Elapsed.app
    ln -s /Applications build/dmg/Applications
    hdiutil create -quiet -volname Elapsed -srcfolder build/dmg -ov -format UDZO "$dmg"
    rm -rf build/dmg
    echo "$dmg"
}

make_zip() {
    local zip="build/Elapsed-$VERSION.zip"
    rm -f "$zip"
    ditto -c -k --keepParent "$APP" "$zip"
    echo "$zip"
}

# MARK: - Sign and package

case "$MODE" in
build | install)
    codesign --force -s - --entitlements StatusTimer/Elapsed.entitlements "$APP"
    echo "Built: $APP"
    ;;

release)
    DEV_ID=$(identity "Developer ID Application")
    if [ -z "$DEV_ID" ]; then
        codesign --force -s - --entitlements StatusTimer/Elapsed.entitlements "$APP"
        DMG=$(make_dmg)
        ZIP=$(make_zip)
        echo "Built: $DMG and $ZIP (universal, ad-hoc signed)"
        echo "No Developer ID certificate, so not notarized: people open it the first time with"
        echo "right-click › Open, or: xattr -dr com.apple.quarantine /Applications/Elapsed.app"
        exit
    fi

    echo "Signing with $DEV_ID"
    codesign --force --options runtime --timestamp -s "$DEV_ID" \
        --entitlements StatusTimer/Elapsed.entitlements "$APP"
    DMG=$(make_dmg)
    codesign --force --timestamp -s "$DEV_ID" "$DMG"

    echo "Notarizing (takes a few minutes)..."
    if ! xcrun notarytool submit "$DMG" --keychain-profile elapsed-notary --wait; then
        echo "Notarization failed. Save credentials once with:"
        echo "    xcrun notarytool store-credentials elapsed-notary"
        exit 1
    fi
    xcrun stapler staple "$DMG"
    xcrun stapler staple "$APP"
    ZIP=$(make_zip)
    echo "Built: $DMG and $ZIP (universal, Developer ID signed, notarized)"
    ;;

appstore)
    # The signature's entitlements must name the same team and app as the profile.
    security cms -D -i "$PROFILE" > build/profile.plist
    APP_IDENTIFIER=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:com.apple.application-identifier" build/profile.plist)
    TEAM=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:com.apple.developer.team-identifier" build/profile.plist)
    cp StatusTimer/Elapsed-AppStore.entitlements build/appstore.entitlements
    /usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string $APP_IDENTIFIER" build/appstore.entitlements
    /usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string $TEAM" build/appstore.entitlements

    cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"
    codesign --force -s "$APP_ID" --entitlements build/appstore.entitlements "$APP"
    PKG="build/Elapsed-$VERSION.pkg"
    productbuild --component "$APP" /Applications --sign "$PKG_ID" "$PKG"
    rm build/profile.plist build/appstore.entitlements
    echo "Built: $PKG — upload it with Transporter. Raise CFBundleVersion for every upload."
    ;;
esac

if [ "$MODE" = install ]; then
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
fi
