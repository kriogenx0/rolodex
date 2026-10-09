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
        ScrollView {
            VStack(spacing: 20) {
                header
                actionBar

                if !contact.phoneNumbers.isEmpty {
                    card {
                        ForEach(Array(contact.phoneNumbers.enumerated()), id: \.offset) { index, labeled in
                            if index > 0 { Divider() }
                            phoneRow(labeled)
                        }
                    }
                }

                if !contact.emailAddresses.isEmpty {
                    card {
                        ForEach(Array(contact.emailAddresses.enumerated()), id: \.offset) { index, labeled in
                            if index > 0 { Divider() }
                            fieldRow(label: CNLabeledValue<NSString>.localizedString(forLabel: labeled.label ?? ""),
                                     value: labeled.value as String, fieldName: "email address")
                        }
                    }
                }

                if !contact.postalAddresses.isEmpty {
                    card {
                        ForEach(Array(contact.postalAddresses.enumerated()), id: \.offset) { index, labeled in
                            if index > 0 { Divider() }
                            fieldRow(label: CNLabeledValue<CNPostalAddress>.localizedString(forLabel: labeled.label ?? ""),
                                     value: CNPostalAddressFormatter.string(from: labeled.value, style: .mailingAddress),
                                     fieldName: "postal address")
                        }
                    }
                }

                groupsCard
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            avatar
                .padding(.bottom, 6)

            HStack(spacing: 6) {
                TextField("", text: $givenName, prompt: Text("First Name"))
                    .accessibilityLabel("First Name")
                    .multilineTextAlignment(.trailing)
                TextField("", text: $familyName, prompt: Text("Last Name"))
                    .accessibilityLabel("Last Name")
                    .multilineTextAlignment(.leading)
            }
            .font(.system(size: 26, weight: .semibold))

            VStack(spacing: 2) {
                TextField("", text: $jobTitle, prompt: Text("Job Title"))
                    .accessibilityLabel("Job Title")
                TextField("", text: $organizationName, prompt: Text("Company"))
                    .accessibilityLabel("Company")
            }
            .font(.title3)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .textFieldStyle(.plain)
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var avatar: some View {
        let size: CGFloat = 120
        if contact.imageDataAvailable,
           let data = imageData ?? contact.thumbnailImageData,
           let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle().fill(LinearGradient(colors: contact.posterGradient, startPoint: .top, endPoint: .bottom))
                if contact.isCompany {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: size * 0.4))
                } else {
                    Text(contact.initials)
                        .font(.system(size: size * 0.4, weight: .medium))
                }
            }
            .foregroundStyle(.white)
            .frame(width: size, height: size)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            actionButton("Message", systemImage: "message.fill", enabled: contact.primaryPhone != nil) {
                if let phone = contact.primaryPhone { open(scheme: "sms", target: phone) }
            }
            actionButton("Call", systemImage: "phone.fill", enabled: contact.primaryPhone != nil) {
                if let phone = contact.primaryPhone { open(scheme: "tel", target: phone) }
            }
            actionButton("Video", systemImage: "video.fill", enabled: contact.primaryPhone != nil || contact.primaryEmail != nil) {
                if let target = contact.primaryPhone ?? contact.primaryEmail { open(scheme: "facetime", target: target) }
            }
            actionButton("Mail", systemImage: "envelope.fill", enabled: contact.primaryEmail != nil) {
                if let email = contact.primaryEmail { open(scheme: "mailto", target: email) }
            }
        }
    }

    private func actionButton(_ title: String, systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Color.accentColor : Color.secondary.opacity(0.6))
        .disabled(!enabled)
    }

    // MARK: - Cards

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private func fieldRow(label: String, value: String, fieldName: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .modifier(ContactFieldCopy(value: value, fieldName: fieldName))
    }

    private var groupsCard: some View {
        let memberGroups = viewModel.groups.filter { viewModel.membership[contact.identifier]?.contains($0.identifier) == true }
        let remainingGroups = viewModel.groups.filter { !(viewModel.membership[contact.identifier]?.contains($0.identifier) ?? false) }
        return card {
            VStack(alignment: .leading, spacing: 6) {
                Text("Groups")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
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

    private func phoneRow(_ labeled: CNLabeledValue<CNPhoneNumber>) -> some View {
        let number = labeled.value.stringValue
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: labeled.label ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(number)
                    .textSelection(.enabled)
            }
            Spacer()
            Button {
                open(scheme: "sms", target: number)
            } label: {
                Image(systemName: "message.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .help("Text")

            Button {
                open(scheme: "tel", target: number)
            } label: {
                Image(systemName: "phone.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .help("Call")
        }
        .padding(.vertical, 8)
        .modifier(ContactFieldCopy(value: number, fieldName: "phone number"))
    }

    private func open(scheme: String, target: String) {
        let cleaned = scheme == "mailto" ? target : target.filter { $0.isNumber || $0 == "+" }
        let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleaned
        guard let url = URL(string: "\(scheme):\(encoded)") else { return }
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
