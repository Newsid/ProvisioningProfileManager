Provisioning Profile Manager 1.0
=================================

Lists, inspects and cleans up the provisioning profiles installed on your Mac.
Requires macOS 14 (Sonoma) or later. Runs on both Apple Silicon and Intel Macs.

Install
-------
1. Open ProvisioningProfileManager-1.0.dmg and drag the app into Applications
   (or unzip ProvisioningProfileManager-1.0.zip and move the app to Applications).
2. The app is not notarized by Apple, so macOS blocks it the first time:
   - Double-click the app and dismiss the warning.
   - Open System Settings > Privacy & Security, scroll down and click "Open Anyway"
     next to the message about "Provisioning Profile Manager". Confirm with your password.
   Alternatively, run this once in Terminal:
     xattr -dr com.apple.quarantine "/Applications/Provisioning Profile Manager.app"

Notes
-----
- Profiles are read from ~/Library/Developer/Xcode/UserData/Provisioning Profiles
  and ~/Library/MobileDevice/Provisioning Profiles.
- Deleted profiles are moved to the Trash, so they can be restored from there.
