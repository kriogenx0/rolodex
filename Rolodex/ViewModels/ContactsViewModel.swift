import Contacts
import Combine
import Foundation

enum SidebarSelection: Hashable {
    case allContacts
    case group(String)
    case smartGroup(UUID)
    case insights
}

@MainActor
final class ContactsViewModel: ObservableObject {
    @Published var contacts: [CNContact] = []
    @Published var groups: [CNGroup] = []
    @Published var membership: [String: Set<String>] = [:]
    @Published var smartGroups: [SmartGroup] = []
    @Published var hiddenGroupIdentifiers: Set<String> = []
    @Published var blockedContactIdentifiers: Set<String> = []
    @Published var selection: SidebarSelection = .allContacts
    @Published var searchText: String = ""
    @Published var selectedContactIDs: Set<String> = []
    @Published var authorizationDenied = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let contactsService = ContactsService.shared
    private let dataStore = AppDataStore.shared
    private var notificationObserver: NSObjectProtocol?

    init() {
        smartGroups = dataStore.data.smartGroups
        hiddenGroupIdentifiers = dataStore.data.hiddenGroupIdentifiers
        blockedContactIdentifiers = dataStore.data.blockedContactIdentifiers
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .CNContactStoreDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAll()
            }
        }
    }

    deinit {
        if let notificationObserver {
            NotificationCenter.default.removeObserver(notificationObserver)
        }
    }

    func start() async {
        let granted = await contactsService.requestAccess()
        authorizationDenied = !granted
        guard granted else { return }
        await refreshAll()
    }

    func refreshAll() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetchedGroups = try contactsService.fetchGroups()
            let fetchedContacts = try contactsService.fetchAllContacts()
            let fetchedMembership = try contactsService.fetchMembership(for: fetchedGroups)
            groups = fetchedGroups.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            contacts = fetchedContacts.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            membership = fetchedMembership
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Derived data

    var contactsByID: [String: CNContact] {
        Dictionary(uniqueKeysWithValues: contacts.map { ($0.identifier, $0) })
    }

    var visibleContacts: [CNContact] {
        var base: [CNContact]
        switch selection {
        case .allContacts:
            let hiddenSmartGroups = smartGroups.filter { $0.isHiddenFromAllContacts }
            let hiddenBySmartGroup = Set(hiddenSmartGroups.flatMap { evaluate(smartGroup: $0).map(\.identifier) })
            base = contacts.filter { contact in
                let groupIDs = membership[contact.identifier] ?? []
                guard groupIDs.isDisjoint(with: hiddenGroupIdentifiers) else { return false }
                return !hiddenBySmartGroup.contains(contact.identifier)
            }
        case .group(let identifier):
            base = contacts.filter { membership[$0.identifier]?.contains(identifier) == true }
        case .smartGroup(let id):
            guard let smartGroup = smartGroups.first(where: { $0.id == id }) else { return [] }
            base = evaluate(smartGroup: smartGroup)
        case .insights:
            base = []
        }

        guard !searchText.isEmpty else { return base }
        let needle = searchText.lowercased()
        return base.filter { contact in
            contact.displayName.lowercased().contains(needle)
                || (contact.primaryEmail?.lowercased().contains(needle) ?? false)
                || (contact.primaryPhone?.lowercased().contains(needle) ?? false)
                || contact.organizationName.lowercased().contains(needle)
        }
    }

    func evaluate(smartGroup: SmartGroup) -> [CNContact] {
        guard !smartGroup.rules.isEmpty else { return [] }
        return contacts.filter { contact in
            let groupIDs = membership[contact.identifier] ?? []
            let results = smartGroup.rules.map { rule in
                contact.matches(field: rule.field, operator: rule.op, value: rule.value, groupIdentifiers: groupIDs)
            }
            switch smartGroup.matchType {
            case .all: return results.allSatisfy { $0 }
            case .any: return results.contains(true)
            }
        }
    }

    // MARK: - Group management

    func isGroupHidden(_ identifier: String) -> Bool {
        hiddenGroupIdentifiers.contains(identifier)
    }

    func toggleGroupHidden(_ identifier: String) {
        if hiddenGroupIdentifiers.contains(identifier) {
            hiddenGroupIdentifiers.remove(identifier)
        } else {
            hiddenGroupIdentifiers.insert(identifier)
        }
        dataStore.update { $0.hiddenGroupIdentifiers = self.hiddenGroupIdentifiers }
    }

    func isContactBlocked(_ identifier: String) -> Bool {
        blockedContactIdentifiers.contains(identifier)
    }

    func toggleBlocked(_ identifier: String) {
        if blockedContactIdentifiers.contains(identifier) {
            blockedContactIdentifiers.remove(identifier)
        } else {
            blockedContactIdentifiers.insert(identifier)
        }
        dataStore.update { $0.blockedContactIdentifiers = self.blockedContactIdentifiers }
    }

    func createGroup(named name: String) {
        do {
            try contactsService.createGroup(named: name)
            Task { await refreshAll() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rename(group: CNGroup, to newName: String) {
        do {
            try contactsService.rename(group: group, to: newName)
            Task { await refreshAll() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(group: CNGroup) {
        do {
            try contactsService.delete(group: group)
            if selection == .group(group.identifier) {
                selection = .allContacts
            }
            Task { await refreshAll() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func merge(source: CNGroup, into destination: CNGroup) {
        do {
            try contactsService.mergeGroup(source, into: destination)
            if selection == .group(source.identifier) {
                selection = .group(destination.identifier)
            }
            Task { await refreshAll() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func membershipState(for contactIDs: Set<String>, in groupIdentifier: String) -> Bool? {
        guard !contactIDs.isEmpty else { return false }
        let states = contactIDs.map { membership[$0]?.contains(groupIdentifier) == true }
        if states.allSatisfy({ $0 }) { return true }
        if states.allSatisfy({ !$0 }) { return false }
        return nil
    }

    func setMembership(_ isMember: Bool, contactIDs: Set<String>, group: CNGroup) {
        let targetContacts = contactIDs.compactMap { contactsByID[$0] }
        guard !targetContacts.isEmpty else { return }
        do {
            if isMember {
                try contactsService.addContacts(targetContacts, to: group)
            } else {
                try contactsService.removeContacts(targetContacts, from: group)
            }
            Task { await refreshAll() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSelectedContacts() {
        let targets = selectedContactIDs.compactMap { contactsByID[$0] }
        guard !targets.isEmpty else { return }
        do {
            try contactsService.delete(targets)
            selectedContactIDs.removeAll()
            Task { await refreshAll() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveContact(_ mutable: CNMutableContact) {
        do {
            try contactsService.update(mutable)
            Task { await refreshAll() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createContact(_ mutable: CNMutableContact, groups: [CNGroup]) {
        do {
            try contactsService.createContact(mutable, in: groups)
            Task { await refreshAll() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Smart groups

    func upsert(smartGroup: SmartGroup) {
        if let index = smartGroups.firstIndex(where: { $0.id == smartGroup.id }) {
            smartGroups[index] = smartGroup
        } else {
            smartGroups.append(smartGroup)
        }
        dataStore.update { $0.smartGroups = self.smartGroups }
    }

    func deleteSmartGroup(_ smartGroup: SmartGroup) {
        smartGroups.removeAll { $0.id == smartGroup.id }
        if selection == .smartGroup(smartGroup.id) {
            selection = .allContacts
        }
        dataStore.update { $0.smartGroups = self.smartGroups }
    }

    // MARK: - Insights

    struct GroupStat: Identifiable {
        var id: String { identifier }
        let identifier: String
        let name: String
        let count: Int
    }

    struct OverlapPair: Identifiable {
        var id: String { "\(first)-\(second)" }
        let first: String
        let second: String
        let firstName: String
        let secondName: String
        let overlapCount: Int
        let overlapFraction: Double
    }

    var groupStats: [GroupStat] {
        groups.map { group in
            let count = contacts.filter { membership[$0.identifier]?.contains(group.identifier) == true }.count
            return GroupStat(identifier: group.identifier, name: group.name, count: count)
        }
        .sorted { $0.count > $1.count }
    }

    var emptyGroups: [CNGroup] {
        groups.filter { group in
            !contacts.contains { membership[$0.identifier]?.contains(group.identifier) == true }
        }
    }

    var contactsWithoutGroup: [CNContact] {
        contacts.filter { (membership[$0.identifier] ?? []).isEmpty }
    }

    var overlappingGroupPairs: [OverlapPair] {
        var results: [OverlapPair] = []
        for i in 0..<groups.count {
            for j in (i + 1)..<groups.count {
                let a = groups[i]
                let b = groups[j]
                let membersA = Set(contacts.filter { membership[$0.identifier]?.contains(a.identifier) == true }.map(\.identifier))
                let membersB = Set(contacts.filter { membership[$0.identifier]?.contains(b.identifier) == true }.map(\.identifier))
                guard !membersA.isEmpty, !membersB.isEmpty else { continue }
                let overlap = membersA.intersection(membersB)
                guard !overlap.isEmpty else { continue }
                let smaller = min(membersA.count, membersB.count)
                let fraction = Double(overlap.count) / Double(smaller)
                if fraction >= 0.5 {
                    results.append(
                        OverlapPair(
                            first: a.identifier,
                            second: b.identifier,
                            firstName: a.name,
                            secondName: b.name,
                            overlapCount: overlap.count,
                            overlapFraction: fraction
                        )
                    )
                }
            }
        }
        return results.sorted { $0.overlapFraction > $1.overlapFraction }
    }
}
