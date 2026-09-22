import AppKit
import Contacts
import SwiftUI

struct ContactDetailView: View {
    @EnvironmentObject var viewModel: ContactsViewModel
    let contact: CNContact

    @State private var givenName = ""
    @State private var familyName = ""
    @State private var organizationName = ""
    @State private var jobTitle = ""
    @State private var isEditing = false
    @State private var vCardURL: URL?

    var body: some View {
        Form {
            Section("Name") {
                if isEditing {
                    TextField("First Name", text: $givenName)
                    TextField("Last Name", text: $familyName)
                    TextField("Company", text: $organizationName)
                    TextField("Job Title", text: $jobTitle)
                } else {
                    HStack {
                        LabeledContent("Name", value: contact.displayName)
                        if contact.isCompany {
                            Image(systemName: "building.2.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !contact.organizationName.isEmpty {
                        LabeledContent("Company", value: contact.organizationName)
                    }
                    if !contact.jobTitle.isEmpty {
                        LabeledContent("Job Title", value: contact.jobTitle)
                    }
                }
            }

            Section("Phone") {
                if contact.phoneNumbers.isEmpty {
                    Text("No phone numbers").foregroundStyle(.secondary)
                }
                ForEach(Array(contact.phoneNumbers.enumerated()), id: \.offset) { _, labeled in
                    phoneRow(labeled)
                }
            }

            Section("Email") {
                if contact.emailAddresses.isEmpty {
                    Text("No email addresses").foregroundStyle(.secondary)
                }
                ForEach(Array(contact.emailAddresses.enumerated()), id: \.offset) { _, labeled in
                    LabeledContent(CNLabeledValue<NSString>.localizedString(forLabel: labeled.label ?? ""), value: labeled.value as String)
                }
            }

            Section("Groups") {
                let memberGroups = viewModel.groups.filter { viewModel.membership[contact.identifier]?.contains($0.identifier) == true }
                if memberGroups.isEmpty {
                    Text("Not in any group").foregroundStyle(.secondary)
                }
                ForEach(memberGroups, id: \.identifier) { group in
                    HStack {
                        Label(group.name, systemImage: "folder.fill")
                        Spacer()
                        Button(role: .destructive) {
                            viewModel.setMembership(false, contactIDs: [contact.identifier], group: group)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
                let remainingGroups = viewModel.groups.filter { !(viewModel.membership[contact.identifier]?.contains($0.identifier) ?? false) }
                if !remainingGroups.isEmpty {
                    Menu("Add to Group…") {
                        ForEach(remainingGroups, id: \.identifier) { group in
                            Button(group.name) {
                                viewModel.setMembership(true, contactIDs: [contact.identifier], group: group)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(contact.displayName)
        .toolbar {
            ToolbarItemGroup {
                if isEditing {
                    Button("Cancel") { isEditing = false; loadFields() }
                    Button("Save") { save() }
                } else {
                    Button("Edit") { isEditing = true }
                    if let vCardURL {
                        ShareLink(item: vCardURL) {
                            Label("Share Contact", systemImage: "square.and.arrow.up")
                        }
                    }
                    Menu {
                        Button(viewModel.isContactBlocked(contact.identifier) ? "Unblock Contact" : "Block Contact", role: viewModel.isContactBlocked(contact.identifier) ? nil : .destructive) {
                            viewModel.toggleBlocked(contact.identifier)
                        }
                        Divider()
                        Button("Delete Contact", role: .destructive) {
                            viewModel.selectedContactIDs = [contact.identifier]
                            viewModel.deleteSelectedContacts()
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            loadFields()
            vCardURL = makeVCardURL()
        }
        .onChange(of: contact.identifier) { _, _ in
            loadFields()
            vCardURL = makeVCardURL()
        }
    }

    @ViewBuilder
    private func phoneRow(_ labeled: CNLabeledValue<CNPhoneNumber>) -> some View {
        HStack {
            LabeledContent(CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: labeled.label ?? ""), value: labeled.value.stringValue)
            Spacer()
            Button {
                open(scheme: "tel", number: labeled.value.stringValue)
            } label: {
                Image(systemName: "phone.fill")
            }
            .buttonStyle(.plain)
            .help("Call")

            Button {
                open(scheme: "sms", number: labeled.value.stringValue)
            } label: {
                Image(systemName: "message.fill")
            }
            .buttonStyle(.plain)
            .help("Text")
        }
    }

    private func open(scheme: String, number: String) {
        let digits = number.filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "\(scheme):\(digits)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func makeVCardURL() -> URL? {
        guard let data = try? CNContactVCardSerialization.data(with: [contact]) else { return nil }
        let fileName = contact.displayName.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).vcf")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func loadFields() {
        givenName = contact.givenName
        familyName = contact.familyName
        organizationName = contact.organizationName
        jobTitle = contact.jobTitle
    }

    private func save() {
        guard let mutable = contact.mutableCopy() as? CNMutableContact else { return }
        mutable.givenName = givenName
        mutable.familyName = familyName
        mutable.organizationName = organizationName
        mutable.jobTitle = jobTitle
        viewModel.saveContact(mutable)
        isEditing = false
    }
}

struct NewContactSheet: View {
    @EnvironmentObject var viewModel: ContactsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var givenName = ""
    @State private var familyName = ""
    @State private var organizationName = ""
    @State private var selectedGroupIDs: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Contact").font(.title2).bold()
            Form {
                TextField("First Name", text: $givenName)
                TextField("Last Name", text: $familyName)
                TextField("Company", text: $organizationName)
                if !viewModel.groups.isEmpty {
                    Section("Add to Groups") {
                        ForEach(viewModel.groups, id: \.identifier) { group in
                            Toggle(group.name, isOn: Binding(
                                get: { selectedGroupIDs.contains(group.identifier) },
                                set: { isOn in
                                    if isOn { selectedGroupIDs.insert(group.identifier) } else { selectedGroupIDs.remove(group.identifier) }
                                }
                            ))
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    let mutable = CNMutableContact()
                    mutable.givenName = givenName
                    mutable.familyName = familyName
                    mutable.organizationName = organizationName
                    let groups = viewModel.groups.filter { selectedGroupIDs.contains($0.identifier) }
                    viewModel.createContact(mutable, groups: groups)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(givenName.isEmpty && familyName.isEmpty && organizationName.isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
    }
}
