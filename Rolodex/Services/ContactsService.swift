import Contacts
import Foundation

struct ContactsSnapshot {
    let contacts: [CNContact]
    let groups: [CNGroup]
    let membership: [String: Set<String>]
    let contactsByID: [String: CNContact]
    let membersByGroup: [String: Set<String>]
    let searchTextByID: [String: [String]]

    init(contacts: [CNContact], groups: [CNGroup], membership: [String: Set<String>]) {
        // Format each name once, rather than on every sorting comparison.
        let namedContacts = contacts.map { ($0, $0.displayName) }
        self.contacts = namedContacts.sorted {
            $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending
        }.map { $0.0 }
        self.groups = groups.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        self.membership = membership
        contactsByID = Dictionary(uniqueKeysWithValues: contacts.map { ($0.identifier, $0) })
        searchTextByID = Dictionary(uniqueKeysWithValues: namedContacts.map { contact, name in
            (contact.identifier, [name, contact.primaryEmail ?? "", contact.primaryPhone ?? "", contact.organizationName]
                .map { $0.lowercased() })
        })
        var members: [String: Set<String>] = [:]
        for contact in contacts {
            for groupID in membership[contact.identifier] ?? [] {
                members[groupID, default: []].insert(contact.identifier)
            }
        }
        membersByGroup = members
    }
}

// Serialize Contacts I/O away from the main actor, including writes.
actor ContactsService {
    static let shared = ContactsService()

    private let store = CNContactStore()

    static let keysToFetch: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactPostalAddressesKey as CNKeyDescriptor,
        CNContactTypeKey as CNKeyDescriptor,
        CNContactImageDataAvailableKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
    ]

    func fetchSnapshot() throws -> ContactsSnapshot {
        let groups = try fetchGroups()
        return try ContactsSnapshot(
            contacts: fetchAllContacts(), groups: groups,
            membership: fetchMembership(for: groups)
        )
    }

    func fetchImageData(identifier: String) throws -> Data? {
        try store.unifiedContact(withIdentifier: identifier, keysToFetch: [CNContactImageDataKey as CNKeyDescriptor]).imageData
    }

    func exportVCardURL(identifier: String, name: String) throws -> URL {
        let contact = try store.unifiedContact(withIdentifier: identifier, keysToFetch: [CNContactVCardSerialization.descriptorForRequiredKeys()])
        let data = try CNContactVCardSerialization.data(with: [contact])
        let fileName = name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).vcf")
        try data.write(to: url, options: .atomic)
        return url
    }

    func requestAccess() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        print("Rolodex: Contacts TCC status at startup = \(status)")
        switch status {
        case .authorized, .limited:
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
        // The snapshot sorts by display name, so don't also sort in the store.
        request.sortOrder = .none
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
