import Foundation

enum ProfileType: String, CaseIterable, Identifiable, Hashable, Sendable {
    case development
    case adHoc
    case appStore
    case enterprise
    case developerID
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .development: "Development"
        case .adHoc: "Ad Hoc"
        case .appStore: "App Store"
        case .enterprise: "Enterprise"
        case .developerID: "Developer ID"
        case .unknown: "Unknown"
        }
    }

    var symbol: String {
        switch self {
        case .development: "hammer.fill"
        case .adHoc: "person.2.fill"
        case .appStore: "bag.fill"
        case .enterprise: "building.2.fill"
        case .developerID: "checkmark.shield.fill"
        case .unknown: "questionmark.circle"
        }
    }
}
