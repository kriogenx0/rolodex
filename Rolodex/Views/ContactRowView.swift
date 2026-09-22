import AppKit
import Contacts
import SwiftUI

struct ContactRowView: View {
    let contact: CNContact

    var body: some View {
        HStack(spacing: 10) {
            avatar
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
        if !contact.organizationName.isEmpty { return contact.organizationName }
        return contact.primaryEmail ?? contact.primaryPhone
    }

    @ViewBuilder
    private var avatar: some View {
        if contact.imageDataAvailable,
           let data = contact.thumbnailImageData,
           let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle().fill(Color.secondary.opacity(0.25))
                if contact.isCompany {
                    Image(systemName: "building.2.fill")
                        .font(.caption)
                } else {
                    Text(contact.initials)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            .frame(width: 32, height: 32)
        }
    }
}
