# Provisioning Profile Manager

A native macOS app to list, inspect and clean up the provisioning profiles installed on your Mac.

Xcode keeps every provisioning profile you have ever downloaded, and over time the folder fills up with expired, duplicated and unreadable files that Xcode itself gives you no way to browse. Provisioning Profile Manager shows them all in one window, tells you which ones you can actually sign with, and lets you remove the ones you no longer need.

## Features

- **Everything in one place:** reads both profile folders: `~/Library/Developer/Xcode/UserData/Provisioning Profiles` (Xcode 16+) and the legacy `~/Library/MobileDevice/Provisioning Profiles`. Profiles found in both are shown once.
- **Health at a glance:** sidebar sections for *Expiring Soon* and *Expired & Invalid*, plus one per profile type (Development, Ad Hoc, App Store, Enterprise, Developer ID).
- **Certificate check against your keychain:** a profile only counts as usable if one of its certificates is installed with its private key. The app flags profiles with no installed certificate, certificates that are expired or about to expire, and valid certificates you have that the profile doesn't include (the profile needs regenerating).
- **Full details:** name, UUID, App ID, bundle ID, team, platforms, dates, certificates, devices, capabilities and entitlements, plus the raw plist.
- **Search, sort and group:** filter by name or bundle ID, sort by name, bundle ID or expiration date, and group profiles by bundle ID.
- **Import:** drag profiles (or folders containing them) onto the window, or use *File › Import*. Profiles are copied into Xcode's folder as `<UUID>.mobileprovision`, and ones already installed are skipped.
- **Export:** save selected profiles named after the profile (e.g. `My App Development.mobileprovision`) instead of their UUID.
- **Safe delete:** profiles are moved to the Trash, so you can restore them. *Expired & Invalid* offers a one-click cleanup.
- **Live updates:** the list refreshes when profiles change on disk (e.g. when Xcode downloads new ones).
- **Text zoom:** ⌘+ / ⌘- / ⌘0.

## Requirements

macOS 14 (Sonoma) or later, on Apple Silicon or Intel.

## Install

Download the `.dmg` or `.zip` from the [Releases](../../releases) page and move **Provisioning Profile Manager** to Applications.

The app is signed ad hoc and not notarized by Apple, so macOS blocks it the first time you open it:

1. Double-click the app and dismiss the warning.
2. Open **System Settings › Privacy & Security**, scroll down and click **Open Anyway** next to the message about Provisioning Profile Manager.

Alternatively, run this once in Terminal:

```sh
xattr -dr com.apple.quarantine "/Applications/Provisioning Profile Manager.app"
```

The app is not sandboxed, because it needs to read and delete files in `~/Library`. It makes no network connections.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘O | Import profiles |
| ⌘E | Export selected profiles |
| ⌘R | Refresh |
| ⇧⌘R | Show selected profiles in Finder |
| ⌘F | Search |
| ⌫ | Move selected profiles to Trash |
| ⌘+ / ⌘- / ⌘0 | Zoom in / zoom out / actual size |

## Building from source

Requires Xcode 16 or later. There are no third-party dependencies.

```sh
# Build and run
xcodebuild -scheme ProvisioningProfileManager -destination 'platform=macOS' -derivedDataPath .build/DerivedData build
open .build/DerivedData/Build/Products/Debug/ProvisioningProfileManager.app

# Run the tests
xcodebuild test -scheme ProvisioningProfileManager -destination 'platform=macOS' -derivedDataPath .build/DerivedData

# Universal Release build packaged as dist/*.dmg and dist/*.zip
scripts/package.sh
```

Or open `ProvisioningProfileManager.xcodeproj` in Xcode and press Run.

## License

[MIT](LICENSE)
