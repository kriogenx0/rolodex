import Contacts
import Foundation

private actor SnapshotLoader {
    let snapshot: ContactsSnapshot
    private(set) var calls = 0
    private(set) var active = 0
    private(set) var maximumActive = 0
    var shouldFail = false

    init(snapshot: ContactsSnapshot) { self.snapshot = snapshot }

    func setFailure(_ value: Bool) { shouldFail = value }

    func load() async throws -> ContactsSnapshot {
        calls += 1
        active += 1
        maximumActive = max(maximumActive, active)
        defer { active -= 1 }
        try await Task.sleep(for: .milliseconds(50))
        if shouldFail { throw NSError(domain: "Test", code: 1) }
        return snapshot
    }
}

@main
struct ContactsPerformanceTests {
    @MainActor
    static func main() async throws {
        // Synthetic fixtures only; these tests never read or write the contact store.
        let alice = CNMutableContact()
        alice.givenName = "Alice"
        alice.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: "alice@example.com" as NSString)]
        let bob = CNMutableContact()
        bob.givenName = "Bob"
        bob.phoneNumbers = [CNLabeledValue(label: CNLabelHome, value: CNPhoneNumber(stringValue: "+1 555 1234"))]
        let carol = CNMutableContact()
        carol.givenName = "Carol"
        let archived = CNMutableGroup()
        archived.name = "Archived"
        let friends = CNMutableGroup()
        friends.name = "Friends"
        let empty = CNMutableGroup()
        empty.name = "Empty"
        let snapshot = ContactsSnapshot(
            contacts: [carol, bob, alice], groups: [friends, empty, archived],
            membership: [alice.identifier: [friends.identifier], bob.identifier: [archived.identifier, friends.identifier]]
        )
        precondition(snapshot.contacts.map(\.givenName) == ["Alice", "Bob", "Carol"])
        precondition(snapshot.groups.map(\.name) == ["Archived", "Empty", "Friends"])
        precondition(snapshot.contactsByID[bob.identifier] === bob)
        precondition(snapshot.membersByGroup[friends.identifier] == [alice.identifier, bob.identifier])

        let loader = SnapshotLoader(snapshot: snapshot)
        let model = ContactsViewModel(loadSnapshot: { try await loader.load() })
        model.smartGroups = []
        model.hiddenGroupIdentifiers = []

        let initialRefresh = Task { await model.refreshAll() }
        while await loader.calls == 0 { await Task.yield() }
        precondition(model.isLoading)
        // A suspended load leaves the main actor available to handle UI work.
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 { group.addTask { await model.refreshAll() } }
        }
        await initialRefresh.value
        let calls = await loader.calls
        let maximumActive = await loader.maximumActive
        precondition(calls == 2, "Overlapping refreshes should produce one follow-up load")
        precondition(maximumActive == 1, "Loads must not overlap")
        precondition(!model.isLoading && model.errorMessage == nil)
        precondition(model.visibleContacts.count == 3)

        model.searchText = "ALICE@EXAMPLE"
        precondition(model.visibleContacts.map(\.identifier) == [alice.identifier])
        model.searchText = "555"
        precondition(model.visibleContacts.map(\.identifier) == [bob.identifier])
        model.searchText = ""
        model.hiddenGroupIdentifiers = [archived.identifier]
        precondition(model.visibleContacts.map(\.givenName) == ["Alice", "Carol"])
        model.selection = .group(archived.identifier)
        precondition(model.visibleContacts.map(\.identifier) == [bob.identifier])
        precondition(model.emptyGroups.map(\.identifier) == [empty.identifier])
        precondition(model.contactsWithoutGroup.map(\.identifier) == [carol.identifier])
        precondition(model.groupStats.first?.count == 2)
        precondition(model.overlappingGroupPairs.count == 1)
        precondition(model.overlappingGroupPairs.first?.overlapFraction == 1)

        await loader.setFailure(true)
        await model.refreshAll()
        precondition(!model.isLoading && model.errorMessage != nil)
        precondition(model.contacts.count == 3, "Failed loads must retain existing contacts")
        await loader.setFailure(false)
        await model.refreshAll()
        precondition(model.errorMessage == nil)

        print("Passed: snapshot indexes, filtering, insights, refresh coalescing, and error recovery.")
    }
}
