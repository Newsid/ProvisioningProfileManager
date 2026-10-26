# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Native macOS app (SwiftUI, Swift 6, macOS 14+) that lists, inspects, imports and deletes the provisioning profiles installed on the Mac. No third-party dependencies.

## Commands

```sh
# Build (Debug)
xcodebuild -scheme ProvisioningProfileManager -destination 'platform=macOS' -derivedDataPath .build/DerivedData build

# Run all tests (Swift Testing)
xcodebuild test -scheme ProvisioningProfileManager -destination 'platform=macOS' -derivedDataPath .build/DerivedData

# Run one suite / one test (Swift Testing names need the trailing "()")
xcodebuild test ... -only-testing:ProvisioningProfileManagerTests/ProfileImporterTests
xcodebuild test ... "-only-testing:ProvisioningProfileManagerTests/ProfileQueryTests/sortsByNameCaseInsensitively()"

# Launch the built app
open .build/DerivedData/Build/Products/Debug/ProvisioningProfileManager.app

# Universal Release build packaged as dist/*.dmg + dist/*.zip
scripts/package.sh

# Regenerate the app icon (drawn in code)
swift scripts/make_icon.swift ProvisioningProfileManager/Assets.xcassets/AppIcon.appiconset
```

There is no linter. SourceKit editor diagnostics such as "Cannot find type … in scope" are spurious (the project has no indexed build context); trust `xcodebuild`.

## Project setup

- `project.pbxproj` was written by hand and uses Xcode 16+ **file-system synchronized groups** (objectVersion 77): any file added under `ProvisioningProfileManager/` or `ProvisioningProfileManagerTests/` is compiled automatically — don't add file references to the pbxproj.
- App Sandbox is **disabled** on purpose: the app reads and deletes files in `~/Library/...`. Signing is ad-hoc (`CODE_SIGN_IDENTITY = "-"`); there is no Developer ID, so builds are not notarized (users need "Open Anyway", see `dist/README.txt`).
- Swift 6 language mode (strict concurrency). The store is `@MainActor`; parsing/loading run in `Task.detached` and operate on `Sendable` value types (entitlements are mirrored into the `PlistValue` enum for this reason).
- `scripts/package.sh` builds the DMG from a blank image + `ditto --norsrc --noextattr` because `hdiutil create -srcfolder` can fail with "Resource busy" and `makehybrid` adds metadata that breaks `codesign --strict`.

## Architecture

Data flows in one direction:

`ProfileLocator` (both profile folders: Xcode 16+ `~/Library/Developer/Xcode/UserData/Provisioning Profiles` and legacy `~/Library/MobileDevice/Provisioning Profiles`)
→ `ProfileParser` (CMS/PKCS#7 decode via `CMSDecoder`, falling back to scanning the file for the XML plist; files that fail become entries with `parseError` instead of being dropped)
→ `CertificateParser` (DER → `CertificateInfo`)
→ `ProfileLoader` (dedupes by UUID across folders into `fileURLs`, then `linkKeychain` with identities from `KeychainChecker`)
→ `ProfileStore` (`@Observable` app state, persisted settings in `UserDefaults`, `FolderWatcher` → debounced reload, delete/import flows)
→ `ProfileQuery` (pure filter / sort / group-by-bundle-ID logic, kept out of the store for testability)
→ SwiftUI views (`NavigationSplitView`: sidebar sections / profile list / detail).

### Certificate & health rules (the non-obvious part)

- Team profiles embed every member's certificate. **Only certificates installed in the keychain with their private key (signing identities) count**; certificates the user doesn't have must never produce warnings or show expiration dates.
- `CertificateSummary.status` (`CertificateStatus`): `.valid` / `.expiringSoon` / `.expired` from the *best* installed certificate, or `.missing` when none is installed.
- "Your" certificates are matched by exact common name, including the team ID, e.g. `Apple Development: Jane Doe (ABCDE12345)`. `keychainCertificatesNotInProfile` lists only *valid* installed certificates the profile doesn't include ("profile needs regenerating").
- `ProvisioningProfile.health(now:warningDays:)` → `ProfileHealth` drives the sidebar sections ("Expiring Soon", "Expired & Invalid"). Order: unreadable → profile expired → certificate missing/expired → expiring soon. The warning threshold (`warningDays`, default 30) is a user setting.
- In the UI, profile alerts are filled capsules with calendar icons and certificate alerts are dashed-outline capsules (`ExpirationBadge`); keep the two visually distinct.

### Other domain rules

- Profile type (`ProfileParser.detectType`): `ProvisionsAllDevices` → Enterprise (or Developer ID if macOS-only); `get-task-allow` → Development; devices without `get-task-allow` → Ad Hoc, unless the certificate is a development one (macOS dev profiles); otherwise App Store.
- Bundle ID = `application-identifier` (or `com.apple.application-identifier`) with the team prefix stripped; may be a wildcard.
- Delete moves files to the Trash (`FileManager.trashItem`) after a confirmation dialog. Import copies (never moves) into the Xcode 16+ folder as `<UUID>.<ext>`, recursing into folders and skipping UUIDs already installed.
- Capabilities shown in the detail view come from the entitlement-key → name table in `Model/Capability.swift`; unknown keys fall into "Other entitlements".

## Tests

Swift Testing (`import Testing`, `#expect`). Build model fixtures with `makeProfile` / `makeCertificate` from `TestSupport.swift`, using the fixed `referenceNow` and `days(_:)` (never `Date()`) so expiration tests are deterministic. Importer tests write unsigned XML plists to a temp folder, which works because of the parser's plist-scan fallback.

## Repository conventions

- `PLAN.md` (original design plan), `.build/` and `dist/*.dmg|zip` are git-ignored; `dist/README.txt` is tracked.
