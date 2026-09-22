import Contacts
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: ContactsViewModel
    @State private var isPresentingNewGroup = false
    @State private var newSmartGroup: SmartGroup?
    @State private var groupPendingRename: CNGroup?
    @State private var renameSheetPresented = false

    var body: some View {
        List(selection: selectionBinding) {
            Section("Contacts") {
                Label("All Contacts", systemImage: "person.2.fill")
                    .badge(viewModel.contacts.count)
                    .tag(SidebarSelection.allContacts)
                Label("Insights", systemImage: "chart.bar.fill")
                    .tag(SidebarSelection.insights)
            }

            Section {
                ForEach(viewModel.groups, id: \.identifier) { group in
                    groupRow(group)
                        .tag(SidebarSelection.group(group.identifier))
                }
            } header: {
                HStack {
                    Text("Groups")
                    Spacer()
                    Button {
                        isPresentingNewGroup = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                ForEach(viewModel.smartGroups) { smartGroup in
                    smartGroupRow(smartGroup)
                        .tag(SidebarSelection.smartGroup(smartGroup.id))
                }
            } header: {
                HStack {
                    Text("Smart Groups")
                    Spacer()
                    Menu {
                        Button("People") {
                            newSmartGroup = SmartGroup(
                                name: "People",
                                rules: [SmartGroupRule(field: .contactType, op: .equals, value: "Person")]
                            )
                        }
                        Button("Companies") {
                            newSmartGroup = SmartGroup(
                                name: "Companies",
                                rules: [SmartGroupRule(field: .contactType, op: .equals, value: "Company")]
                            )
                        }
                        Divider()
                        Button("Custom…") {
                            newSmartGroup = SmartGroup(name: "New Smart Group")
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                }
            }
        }
        .listStyle(.sidebar)
        .sheet(isPresented: $isPresentingNewGroup) {
            GroupEditorSheet(mode: .create) { name in
                viewModel.createGroup(named: name)
            }
        }
        .sheet(item: $newSmartGroup) { smartGroup in
            SmartGroupEditorView(smartGroup: smartGroup) { updated in
                viewModel.upsert(smartGroup: updated)
            }
        }
        .sheet(isPresented: $renameSheetPresented) {
            if let group = groupPendingRename {
                GroupEditorSheet(mode: .rename(group.name)) { newName in
                    viewModel.rename(group: group, to: newName)
                }
            }
        }
    }

    private var selectionBinding: Binding<SidebarSelection?> {
        Binding(
            get: { viewModel.selection },
            set: { if let newValue = $0 { viewModel.selection = newValue } }
        )
    }

    @ViewBuilder
    private func groupRow(_ group: CNGroup) -> some View {
        let count = viewModel.contacts.filter { viewModel.membership[$0.identifier]?.contains(group.identifier) == true }.count
        Label(group.name, systemImage: "folder.fill")
            .badge(count)
            .opacity(viewModel.isGroupHidden(group.identifier) ? 0.5 : 1)
            .contextMenu {
                Button(viewModel.isGroupHidden(group.identifier) ? "Show in All Contacts" : "Hide from All Contacts") {
                    viewModel.toggleGroupHidden(group.identifier)
                }
                Button("Rename…") {
                    groupPendingRename = group
                    renameSheetPresented = true
                }
                if viewModel.groups.count > 1 {
                    Menu("Merge Into…") {
                        ForEach(viewModel.groups.filter { $0.identifier != group.identifier }, id: \.identifier) { other in
                            Button(other.name) {
                                viewModel.merge(source: group, into: other)
                            }
                        }
                    }
                }
                Divider()
                Button("Delete", role: .destructive) {
                    viewModel.delete(group: group)
                }
            }
    }

    @ViewBuilder
    private func smartGroupRow(_ smartGroup: SmartGroup) -> some View {
        let count = viewModel.evaluate(smartGroup: smartGroup).count
        Label(smartGroup.name, systemImage: "wand.and.stars")
            .badge(count)
            .contextMenu {
                Button("Edit…") {
                    newSmartGroup = smartGroup
                }
                Divider()
                Button("Delete", role: .destructive) {
                    viewModel.deleteSmartGroup(smartGroup)
                }
            }
    }
}
