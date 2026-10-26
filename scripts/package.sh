#!/bin/zsh
# Builds a universal Release app and packages it as dist/*.zip and dist/*.dmg.
# Usage: scripts/package.sh
set -euo pipefail

cd "$(dirname "$0")/.."
NAME="Provisioning Profile Manager"
VERSION=$(sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' ProvisioningProfileManager.xcodeproj/project.pbxproj | head -1)
BUILD=.build/Release
STAGE=.build/dmg
APP="$BUILD/Build/Products/Release/ProvisioningProfileManager.app"

rm -rf "$BUILD" "$STAGE" .build/rw.dmg
xcodebuild -scheme ProvisioningProfileManager -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$BUILD" ONLY_ACTIVE_ARCH=NO build -quiet

mkdir -p "$STAGE" dist
ditto --norsrc --noextattr "$APP" "$STAGE/$NAME.app"
codesign --verify --deep --strict "$STAGE/$NAME.app"

rm -f "dist/ProvisioningProfileManager-$VERSION.zip" "dist/ProvisioningProfileManager-$VERSION.dmg"
ditto -c -k --keepParent "$STAGE/$NAME.app" "dist/ProvisioningProfileManager-$VERSION.zip"

# `hdiutil create -srcfolder` often fails with "Resource busy" here, so create a blank
# image, copy the app in without extended attributes and compress it.
hdiutil create -quiet -size 40m -fs HFS+ -volname "$NAME" -type UDIF -layout GPTSPUD .build/rw.dmg
MOUNT=$(hdiutil attach -nobrowse .build/rw.dmg | grep -o '/Volumes/.*')
ditto --norsrc --noextattr "$STAGE/$NAME.app" "$MOUNT/$NAME.app"
ln -s /Applications "$MOUNT/Applications"
codesign --verify --deep --strict "$MOUNT/$NAME.app"
hdiutil detach -quiet "$MOUNT"
hdiutil convert -quiet .build/rw.dmg -format UDZO -o "dist/ProvisioningProfileManager-$VERSION.dmg" -ov
rm -f .build/rw.dmg

ls -lh dist
