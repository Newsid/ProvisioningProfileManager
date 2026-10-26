import Foundation

/// A human readable capability made of one or more entitlement keys.
struct CapabilityGroup: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let symbol: String
    let entries: [Entry]

    struct Entry: Identifiable, Hashable {
        var id: String { key }
        let key: String
        let value: PlistValue
    }
}

enum CapabilityCatalog {
    /// Entitlements that every profile carries and that are not user-facing capabilities.
    static let baseKeys: Set<String> = [
        "application-identifier",
        "com.apple.application-identifier",
        "com.apple.developer.team-identifier",
        "get-task-allow",
        "com.apple.security.get-task-allow",
        "beta-reports-active",
    ]

    /// Entitlement key → (capability name, SF Symbol).
    static let known: [String: (name: String, symbol: String)] = [
        "aps-environment": ("Push Notifications", "bell.badge.fill"),
        "com.apple.developer.aps-environment": ("Push Notifications", "bell.badge.fill"),
        "com.apple.developer.usernotifications.time-sensitive": ("Time Sensitive Notifications", "bell.and.waves.left.and.right"),
        "com.apple.developer.usernotifications.communication": ("Communication Notifications", "message.badge"),
        "com.apple.security.application-groups": ("App Groups", "square.stack.3d.up.fill"),
        "com.apple.developer.associated-domains": ("Associated Domains", "link"),
        "com.apple.developer.associated-domains.mdm-managed": ("Associated Domains", "link"),
        "keychain-access-groups": ("Keychain Sharing", "key.fill"),
        "com.apple.developer.icloud-container-identifiers": ("iCloud", "icloud.fill"),
        "com.apple.developer.icloud-container-development-container-identifiers": ("iCloud", "icloud.fill"),
        "com.apple.developer.icloud-container-environment": ("iCloud", "icloud.fill"),
        "com.apple.developer.icloud-services": ("iCloud", "icloud.fill"),
        "com.apple.developer.ubiquity-container-identifiers": ("iCloud", "icloud.fill"),
        "com.apple.developer.ubiquity-kvstore-identifier": ("iCloud", "icloud.fill"),
        "com.apple.developer.applesignin": ("Sign in with Apple", "apple.logo"),
        "com.apple.developer.healthkit": ("HealthKit", "heart.fill"),
        "com.apple.developer.healthkit.access": ("HealthKit", "heart.fill"),
        "com.apple.developer.healthkit.background-delivery": ("HealthKit", "heart.fill"),
        "com.apple.developer.homekit": ("HomeKit", "house.fill"),
        "com.apple.developer.nfc.readersession.formats": ("NFC Tag Reading", "wave.3.right"),
        "com.apple.developer.siri": ("Siri", "mic.fill"),
        "com.apple.developer.in-app-payments": ("Apple Pay", "creditcard.fill"),
        "com.apple.developer.pass-type-identifiers": ("Wallet", "wallet.pass.fill"),
        "com.apple.developer.networking.networkextension": ("Network Extensions", "network"),
        "com.apple.developer.networking.vpn.api": ("Personal VPN", "lock.shield.fill"),
        "com.apple.developer.networking.wifi-info": ("Access Wi-Fi Information", "wifi"),
        "com.apple.developer.networking.HotspotConfiguration": ("Hotspot Configuration", "personalhotspot"),
        "com.apple.developer.networking.multipath": ("Multipath", "arrow.triangle.branch"),
        "com.apple.developer.game-center": ("Game Center", "gamecontroller.fill"),
        "com.apple.developer.associated-appclip-app-identifiers": ("App Clips", "appclip"),
        "com.apple.developer.parent-application-identifiers": ("App Clips", "appclip"),
        "com.apple.developer.devicecheck.appattest-environment": ("App Attest", "checkmark.seal.fill"),
        "com.apple.developer.default-data-protection": ("Data Protection", "lock.fill"),
        "com.apple.developer.ClassKit-environment": ("ClassKit", "graduationcap.fill"),
        "com.apple.developer.weatherkit": ("WeatherKit", "cloud.sun.fill"),
        "com.apple.developer.family-controls": ("Family Controls", "figure.and.child.holdinghands"),
        "com.apple.developer.kernel.increased-memory-limit": ("Increased Memory Limit", "memorychip.fill"),
        "com.apple.developer.kernel.extended-virtual-addressing": ("Extended Virtual Addressing", "memorychip"),
        "com.apple.developer.maps": ("Maps", "map.fill"),
        "com.apple.external-accessory.wireless-configuration": ("Wireless Accessory Configuration", "antenna.radiowaves.left.and.right"),
        "inter-app-audio": ("Inter-App Audio", "waveform"),
        "com.apple.developer.user-fonts": ("Fonts", "textformat"),
        "com.apple.developer.contacts.notes": ("Contacts Notes", "person.crop.circle"),
        "com.apple.developer.coremedia.hls.low-latency": ("Low-Latency HLS", "play.tv.fill"),
        "com.apple.developer.authentication-services.autofill-credential-provider": ("AutoFill Credential Provider", "person.badge.key.fill"),
        "com.apple.developer.push-to-talk": ("Push to Talk", "mic.badge.plus"),
        "com.apple.developer.shared-with-you": ("Shared with You", "person.2.wave.2.fill"),
        "com.apple.developer.group-session": ("Group Activities", "shareplay"),
        "com.apple.developer.matter.allow-setup-payload": ("Matter", "homekit"),
        "com.apple.developer.carplay-audio": ("CarPlay", "car.fill"),
        "com.apple.developer.carplay-communication": ("CarPlay", "car.fill"),
        "com.apple.developer.carplay-charging": ("CarPlay", "car.fill"),
        "com.apple.developer.carplay-maps": ("CarPlay", "car.fill"),
        "com.apple.developer.carplay-parking": ("CarPlay", "car.fill"),
        "com.apple.developer.carplay-quick-ordering": ("CarPlay", "car.fill"),
        "com.apple.developer.icloud-extended-share-access": ("iCloud", "icloud.fill"),
        "com.apple.developer.fileprovider.testing-mode": ("File Provider Testing Mode", "folder.fill"),
        "com.apple.developer.mail-client": ("Default Mail App", "envelope.fill"),
        "com.apple.developer.web-browser": ("Default Web Browser", "safari.fill"),
        "com.apple.developer.sustained-execution": ("Sustained Execution", "bolt.fill"),
        "com.apple.developer.journal.allow": ("Journaling Suggestions", "book.fill"),
    ]

    struct Classification {
        var capabilities: [CapabilityGroup] = []
        var base: [CapabilityGroup.Entry] = []
        var other: [CapabilityGroup.Entry] = []
    }

    static func classify(_ entitlements: [String: PlistValue]) -> Classification {
        var result = Classification()
        var grouped: [String: (symbol: String, entries: [CapabilityGroup.Entry])] = [:]
        for key in entitlements.keys.sorted() {
            let entry = CapabilityGroup.Entry(key: key, value: entitlements[key]!)
            if baseKeys.contains(key) {
                result.base.append(entry)
            } else if let info = known[key] {
                grouped[info.name, default: (info.symbol, [])].entries.append(entry)
            } else {
                result.other.append(entry)
            }
        }
        result.capabilities = grouped
            .map { CapabilityGroup(name: $0.key, symbol: $0.value.symbol, entries: $0.value.entries) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return result
    }
}
