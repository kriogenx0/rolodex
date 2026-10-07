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
    @State private var vCardURL: URL?
    @State private var imageData: Data?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal)
                .padding(.top, 8)

            HStack(spacing: 8) {
                TextField("", text: $givenName, prompt: Text("First Name"))
                    .accessibilityLabel("First Name")
                TextField("", text: $familyName, prompt: Text("Last Name"))
                    .accessibilityLabel("Last Name")
            }
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal)
            .padding(.top, 8)

            Form {
            Section {
                TextField("Company", text: $organizationName)
                TextField("Job Title", text: $jobTitle)
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
                        .modifier(ContactFieldCopy(value: labeled.value as String, fieldName: "email address"))
                }
            }

            Section("Address") {
                if contact.postalAddresses.isEmpty {
                    Text("No postal addresses").foregroundStyle(.secondary)
                }
                ForEach(Array(contact.postalAddresses.enumerated()), id: \.offset) { _, labeled in
                    let address = CNPostalAddressFormatter.string(from: labeled.value, style: .mailingAddress)
                    LabeledContent(CNLabeledValue<CNPostalAddress>.localizedString(forLabel: labeled.label ?? "")) {
                        Text(address)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .modifier(ContactFieldCopy(value: address, fieldName: "postal address"))
                }
            }

            Section("Groups") {
                let memberGroups = viewModel.groups.filter { viewModel.membership[contact.identifier]?.contains($0.identifier) == true }
                let remainingGroups = viewModel.groups.filter { !(viewModel.membership[contact.identifier]?.contains($0.identifier) ?? false) }
                if memberGroups.isEmpty && remainingGroups.isEmpty {
                    Text("No groups available").foregroundStyle(.secondary)
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(memberGroups, id: \.identifier) { group in
                            groupTag(group)
                        }
                        if !remainingGroups.isEmpty {
                            addGroupTag(remainingGroups)
                        }
                    }
                }
            }
            }
            .formStyle(.grouped)
        }
        .navigationTitle(contact.displayName)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Save") { save() }
                    .disabled(!isDirty)
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
        .onAppear {
            loadFields()
        }
        .onChange(of: contact.identifier) { _, _ in
            loadFields()
        }
        .task(id: contact) {
            vCardURL = nil
            imageData = nil
            let service = ContactsService.shared
            async let photo = try? service.fetchImageData(identifier: contact.identifier)
            async let card = try? service.exportVCardURL(identifier: contact.identifier, name: contact.displayName)
            let (loadedPhoto, loadedCard) = await (photo, card)
            guard !Task.isCancelled else { return }
            imageData = loadedPhoto
            vCardURL = loadedCard
        }
    }

    @ViewBuilder
    private var header: some View {
        ZStack {
            headerBackground
            ContactAvatarView(contact: contact, size: 96)
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .shadow(radius: 6)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var headerBackground: some View {
        if contact.imageDataAvailable,
           let data = imageData ?? contact.thumbnailImageData,
           let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .frame(height: 160)
                .clipped()
                .blur(radius: 20)
                .overlay(Color.black.opacity(0.2))
        } else {
            LinearGradient(colors: contact.posterGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func groupTag(_ group: CNGroup) -> some View {
        HStack(spacing: 4) {
            Text(group.name)
                .font(.caption)
            Button {
                viewModel.setMembership(false, contactIDs: [contact.identifier], group: group)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.15))
        .foregroundStyle(Color.accentColor)
        .clipShape(Capsule())
    }

    private func addGroupTag(_ remainingGroups: [CNGroup]) -> some View {
        Menu {
            ForEach(remainingGroups, id: \.identifier) { group in
                Button(group.name) {
                    viewModel.setMembership(true, contactIDs: [contact.identifier], group: group)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                Text("Add")
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.15))
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
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
        .modifier(ContactFieldCopy(value: labeled.value.stringValue, fieldName: "phone number"))
    }

    private func open(scheme: String, number: String) {
        let digits = number.filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "\(scheme):\(digits)") else { return }
        NSWorkspace.shared.open(url)
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
    }

    private var isDirty: Bool {
        givenName != contact.givenName
            || familyName != contact.familyName
            || organizationName != contact.organizationName
            || jobTitle != contact.jobTitle
    }
}

private struct ContactFieldCopy: ViewModifier {
    let value: String
    let fieldName: String

    @State private var isHovered = false
    @FocusState private var isCopyFocused: Bool

    func body(content: Content) -> some View {
        HStack(spacing: 8) {
            content
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .focused($isCopyFocused)
            .help("Copy \(fieldName)")
            .accessibilityLabel("Copy \(fieldName)")
            .opacity(isHovered || isCopyFocused ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
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
