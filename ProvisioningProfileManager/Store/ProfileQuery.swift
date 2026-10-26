import Foundation

enum SidebarItem: Hashable, Sendable {
    case all
    case expiringSoon
    case expiredOrInvalid
    case type(ProfileType)

    var title: String {
        switch self {
        case .all: "All Profiles"
        case .expiringSoon: "Expiring Soon"
        case .expiredOrInvalid: "Expired & Invalid"
        case .type(let type): type.title
        }
    }
}

enum SearchScope: String, CaseIterable, Identifiable, Sendable {
    case name
    case bundleID

    var id: String { rawValue }
    var title: String { self == .name ? "Name" : "Bundle ID" }
}

enum SortField: String, CaseIterable, Identifiable, Sendable {
    case name
    case bundleID
    case expirationDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: "Name"
        case .bundleID: "Bundle ID"
        case .expirationDate: "Expiration Date"
        }
    }
}

struct ProfileGroup: Identifiable, Hashable {
    /// The bundle ID (empty for unreadable profiles).
    let id: String
    let profiles: [ProvisioningProfile]

    var title: String { id.isEmpty ? "Unknown Bundle ID" : id }
}

/// Pure filtering / sorting / grouping logic, kept separate from the store for testability.
struct ProfileQuery {
    var sidebar: SidebarItem = .all
    var searchText = ""
    var searchScope: SearchScope = .name
    var sortField: SortField = .name
    var ascending = true
    var warningDays = 30
    var now = Date()

    func includes(_ profile: ProvisioningProfile, in item: SidebarItem) -> Bool {
        switch item {
        case .all: true
        case .expiringSoon: profile.health(now: now, warningDays: warningDays) == .expiringSoon
        case .expiredOrInvalid: profile.health(now: now, warningDays: warningDays).isInvalid
        case .type(let type): profile.type == type
        }
    }

    func matchesSearch(_ profile: ProvisioningProfile) -> Bool {
        let text = searchText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return true }
        let field = searchScope == .name ? profile.name : profile.bundleID
        return field.localizedCaseInsensitiveContains(text)
    }

    func apply(to profiles: [ProvisioningProfile]) -> [ProvisioningProfile] {
        sort(profiles.filter { includes($0, in: sidebar) && matchesSearch($0) })
    }

    func sort(_ profiles: [ProvisioningProfile]) -> [ProvisioningProfile] {
        profiles.sorted { lhs, rhs in
            switch compare(lhs, rhs) {
            case .orderedAscending: true
            case .orderedDescending: false
            case .orderedSame: lhs.id < rhs.id
            }
        }
    }

    private func compare(_ lhs: ProvisioningProfile, _ rhs: ProvisioningProfile) -> ComparisonResult {
        let byName = lhs.name.localizedStandardCompare(rhs.name)
        switch sortField {
        case .name:
            return ascending ? byName : byName.inverted
        case .bundleID:
            let result = lhs.bundleID.localizedStandardCompare(rhs.bundleID)
            if result == .orderedSame { return byName }
            return ascending ? result : result.inverted
        case .expirationDate:
            // Profiles without a date always go last.
            switch (lhs.expirationDate, rhs.expirationDate) {
            case (nil, nil): return byName
            case (nil, _): return .orderedDescending
            case (_, nil): return .orderedAscending
            case let (l?, r?):
                if l == r { return byName }
                let result: ComparisonResult = l < r ? .orderedAscending : .orderedDescending
                return ascending ? result : result.inverted
            }
        }
    }

    /// Groups already sorted profiles by bundle ID, keeping the order inside each group.
    func grouped(_ sortedProfiles: [ProvisioningProfile]) -> [ProfileGroup] {
        let groups = Dictionary(grouping: sortedProfiles, by: \.bundleID)
            .map { ProfileGroup(id: $0.key, profiles: $0.value) }
        let descending = sortField == .bundleID && !ascending
        return groups.sorted { lhs, rhs in
            if lhs.id.isEmpty != rhs.id.isEmpty { return rhs.id.isEmpty }
            let result = lhs.id.localizedStandardCompare(rhs.id)
            return descending ? result == .orderedDescending : result == .orderedAscending
        }
    }

    func count(for item: SidebarItem, in profiles: [ProvisioningProfile]) -> Int {
        profiles.count { includes($0, in: item) }
    }
}

private extension ComparisonResult {
    var inverted: ComparisonResult {
        switch self {
        case .orderedAscending: .orderedDescending
        case .orderedDescending: .orderedAscending
        case .orderedSame: .orderedSame
        }
    }
}
