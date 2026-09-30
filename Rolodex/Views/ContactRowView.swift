import AppKit
import Contacts
import SwiftUI

struct ContactRowView: View {
    let contact: CNContact

    var body: some View {
        HStack(spacing: 10) {
            ContactAvatarView(contact: contact, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.body)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String? {
        if !contact.organizationName.isEmpty, contact.organizationName != contact.displayName {
            return contact.organizationName
        }
        return contact.primaryEmail ?? contact.primaryPhone
    }
}
