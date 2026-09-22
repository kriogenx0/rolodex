import Contacts
import SwiftUI

struct BulkGroupAssignMenu: View {
    @EnvironmentObject var viewModel: ContactsViewModel

    var body: some View {
        Menu {
            if viewModel.groups.isEmpty {
                Text("No groups yet")
            }
            ForEach(viewModel.groups, id: \.identifier) { group in
                let state = viewModel.membershipState(for: viewModel.selectedContactIDs, in: group.identifier)
                Button {
                    viewModel.setMembership(!(state == true), contactIDs: viewModel.selectedContactIDs, group: group)
                } label: {
                    HStack {
                        Text(group.name)
                        Spacer()
                        if state == true {
                            Image(systemName: "checkmark")
                        } else if state == nil {
                            Image(systemName: "minus")
                        }
                    }
                }
            }
        } label: {
            Label("Add to Group", systemImage: "folder.badge.plus")
        }
    }
}
