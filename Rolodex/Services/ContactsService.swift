import Contacts
import Foundation

@MainActor
final class ContactsService {
    static let shared = ContactsService()

    let store = CNContactStore()

    static let keysToFetch: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactTypeKey as CNKeyDescriptor,
        CNContactImageDataAvailableKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
    ]

    func requestAccess() async -> Bool {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                store.requestAccess(for: .contacts) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }

    func fetchAllContacts() throws -> [CNContact] {
        var results: [CNContact] = []
        let request = CNContactFetchRequest(keysToFetch: Self.keysToFetch)
        request.sortOrder = .userDefault
        try store.enumerateContacts(with: request) { contact, _ in
            results.append(contact)
        }
        return results
    }

    func fetchGroups() throws -> [CNGroup] {
        try store.groups(matching: nil)
    }

    func fetchMembership(for groups: [CNGroup]) throws -> [String: Set<String>] {
        var membership: [String: Set<String>] = [:]
        for group in groups {
            let predicate = CNContact.predicateForContactsInGroup(withIdentifier: group.identifier)
            let members = try store.unifiedContacts(matching: predicate, keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
            for member in members {
                membership[member.identifier, default: []].insert(group.identifier)
            }
        }
        return membership
    }

    // MARK: - Groups

    @discardableResult
    func createGroup(named name: String) throws -> CNGroup {
        let newGroup = CNMutableGroup()
        newGroup.name = name
        let request = CNSaveRequest()
        request.add(newGroup, toContainerWithIdentifier: nil)
        try store.execute(request)
        return newGroup
    }

    func rename(group: CNGroup, to newName: String) throws {
        guard let mutable = group.mutableCopy() as? CNMutableGroup else { return }
        mutable.name = newName
        let request = CNSaveRequest()
        request.update(mutable)
        try store.execute(request)
    }

    func delete(group: CNGroup) throws {
        guard let mutable = group.mutableCopy() as? CNMutableGroup else { return }
        let request = CNSaveRequest()
        request.delete(mutable)
        try store.execute(request)
    }

    func addContacts(_ contacts: [CNContact], to group: CNGroup) throws {
        let request = CNSaveRequest()
        for contact in contacts {
            request.addMember(contact, to: group)
        }
        try store.execute(request)
    }

    func removeContacts(_ contacts: [CNContact], from group: CNGroup) throws {
        let request = CNSaveRequest()
        for contact in contacts {
            request.removeMember(contact, from: group)
        }
        try store.execute(request)
    }

    func mergeGroup(_ source: CNGroup, into destination: CNGroup) throws {
        let predicate = CNContact.predicateForContactsInGroup(withIdentifier: source.identifier)
        let members = try store.unifiedContacts(matching: predicate, keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])

        let request = CNSaveRequest()
        for member in members {
            request.addMember(member, to: destination)
        }
        if let mutableSource = source.mutableCopy() as? CNMutableGroup {
            request.delete(mutableSource)
        }
        try store.execute(request)
    }

    // MARK: - Contacts

    @discardableResult
    func createContact(_ contact: CNMutableContact, in groups: [CNGroup]) throws -> CNContact {
        let request = CNSaveRequest()
        request.add(contact, toContainerWithIdentifier: nil)
        for group in groups {
            request.addMember(contact, to: group)
        }
        try store.execute(request)
        return contact
    }

    func update(_ contact: CNMutableContact) throws {
        let request = CNSaveRequest()
        request.update(contact)
        try store.execute(request)
    }

    func delete(_ contacts: [CNContact]) throws {
        let request = CNSaveRequest()
        for contact in contacts {
            if let mutable = contact.mutableCopy() as? CNMutableContact {
                request.delete(mutable)
            }
        }
        try store.execute(request)
    }
}
