import Foundation

/// A Sendable, typed mirror of a property-list value (used for entitlements).
enum PlistValue: Hashable, Sendable {
    case string(String)
    case integer(Int)
    case real(Double)
    case bool(Bool)
    case date(Date)
    case data(Data)
    case array([PlistValue])
    case dictionary([String: PlistValue])

    init?(_ any: Any) {
        switch any {
        case let value as String:
            self = .string(value)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else if CFNumberIsFloatType(number) {
                self = .real(number.doubleValue)
            } else {
                self = .integer(number.intValue)
            }
        case let value as Date:
            self = .date(value)
        case let value as Data:
            self = .data(value)
        case let values as [Any]:
            self = .array(values.compactMap(PlistValue.init))
        case let dict as [String: Any]:
            self = .dictionary(dict.compactMapValues(PlistValue.init))
        default:
            return nil
        }
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    /// Multi-line, human readable representation.
    var displayString: String {
        switch self {
        case .string(let value): return value
        case .integer(let value): return String(value)
        case .real(let value): return String(value)
        case .bool(let value): return value ? "Yes" : "No"
        case .date(let value): return value.formatted(date: .abbreviated, time: .shortened)
        case .data(let value): return "<\(value.count) bytes>"
        case .array(let values):
            if values.isEmpty { return "(empty)" }
            return values.map(\.displayString).joined(separator: "\n")
        case .dictionary(let dict):
            if dict.isEmpty { return "(empty)" }
            return dict.keys.sorted().map { "\($0): \(dict[$0]!.displayString)" }.joined(separator: "\n")
        }
    }
}
