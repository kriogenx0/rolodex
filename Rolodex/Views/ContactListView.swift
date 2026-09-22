import Contacts
import SwiftUI

struct ContactListView: View {
    @EnvironmentObject var viewModel: ContactsViewModel
    @State private var isPresentingNewContact = false

    var body: some View {
        List(selection: $viewModel.selectedContactIDs) {
            ForEach(viewModel.visibleContacts, id: \.identifier) { contact in
                ContactRowView(contact: contact)
                    .tag(contact.identifier)
            }
        }
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Search")
        .navigationTitle(title)
        .toolbar {
            ToolbarItemGroup {
                BulkGroupAssignMenu()
                    .disabled(viewModel.selectedContactIDs.isEmpty)
                Button {
                    isPresentingNewContact = true
                } label: {
                    Label("New Contact", systemImage: "person.crop.circle.badge.plus")
                }
                Button(role: .destructive) {
                    viewModel.deleteSelectedContacts()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(viewModel.selectedContactIDs.isEmpty)
            }
        }
        .sheet(isPresented: $isPresentingNewContact) {
            NewContactSheet()
        }
        .overlay {
            if viewModel.visibleContacts.isEmpty {
                ContentUnavailableView(
                    "No Contacts",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text(viewModel.searchText.isEmpty ? "This group has no contacts yet." : "No contacts match your search.")
                )
            }
        }
    }

    private var title: String {
        switch viewModel.selection {
        case .allContacts:
            return "All Contacts"
        case .group(let id):
            return viewModel.groups.first { $0.identifier == id }?.name ?? "Group"
        case .smartGroup(let id):
            return viewModel.smartGroups.first { $0.id == id }?.name ?? "Smart Group"
        case .insights:
            return "Insights"
        }
    }
}
