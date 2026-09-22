import Foundation

enum RuleField: String, Codable, CaseIterable, Identifiable {
    case fullName = "Name"
    case organization = "Company"
    case jobTitle = "Job Title"
    case email = "Email"
    case phone = "Phone"
    case contactType = "Card Type"
    case anyGroup = "Any Group"

    var id: String { rawValue }

    /// Whether this field is matched by picking a fixed value rather than typing free text.
    var usesFixedValues: Bool {
        self == .contactType
    }

    var fixedValues: [String] {
        switch self {
        case .contactType: return ["Person", "Company"]
        default: return []
        }
    }
}

enum RuleOperator: String, Codable, CaseIterable, Identifiable {
    case contains = "contains"
    case equals = "is"
    case beginsWith = "begins with"
    case isSet = "is set"

    var id: String { rawValue }
}

enum MatchType: String, Codable, CaseIterable, Identifiable {
    case all = "All"
    case any = "Any"

    var id: String { rawValue }
}

struct SmartGroupRule: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var field: RuleField = .fullName
    var op: RuleOperator = .contains
    var value: String = ""
}

struct SmartGroup: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var matchType: MatchType = .any
    var rules: [SmartGroupRule] = []
    var isHiddenFromAllContacts: Bool = false
}
