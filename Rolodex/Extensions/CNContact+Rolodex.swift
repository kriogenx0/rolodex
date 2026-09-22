import Contacts
import Foundation

extension CNContact {
    var displayName: String {
        let name = CNContactFormatter.string(from: self, style: .fullName)
        if let name, !name.isEmpty { return name }
        if !organizationName.isEmpty { return organizationName }
        return "No Name"
    }

    var initials: String {
        var components = PersonNameComponents()
        components.givenName = givenName
        components.familyName = familyName
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .abbreviated
        let result = formatter.string(from: components)
        if !result.isEmpty { return result }
        return String(displayName.prefix(1)).uppercased()
    }

    var primaryEmail: String? {
        emailAddresses.first.map { $0.value as String }
    }

    var primaryPhone: String? {
        phoneNumbers.first?.value.stringValue
    }

    var isCompany: Bool {
        contactType == .organization
    }

    var typeLabel: String {
        isCompany ? "Company" : "Person"
    }

    func matches(field: RuleField, operator op: RuleOperator, value: String, groupIdentifiers: Set<String>) -> Bool {
        let needle = value.lowercased()

        func test(_ haystacks: [String]) -> Bool {
            switch op {
            case .isSet:
                return haystacks.contains { !$0.isEmpty }
            case .contains:
                return haystacks.contains { $0.lowercased().contains(needle) }
            case .equals:
                return haystacks.contains { $0.lowercased() == needle }
            case .beginsWith:
                return haystacks.contains { $0.lowercased().hasPrefix(needle) }
            }
        }

        switch field {
        case .fullName:
            return test([displayName])
        case .organization:
            return test([organizationName])
        case .jobTitle:
            return test([jobTitle])
        case .email:
            return test(emailAddresses.map { $0.value as String })
        case .phone:
            return test(phoneNumbers.map { $0.value.stringValue })
        case .contactType:
            if op == .isSet { return true }
            return typeLabel.lowercased() == needle
        case .anyGroup:
            if op == .isSet { return !groupIdentifiers.isEmpty }
            return false
        }
    }
}
