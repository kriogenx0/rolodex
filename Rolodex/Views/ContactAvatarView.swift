import AppKit
import Contacts
import SwiftUI

struct ContactAvatarView: View {
    let contact: CNContact
    var size: CGFloat = 32

    var body: some View {
        if contact.imageDataAvailable,
           let data = contact.thumbnailImageData,
           let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle().fill(Color.secondary.opacity(0.25))
                if contact.isCompany {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: size * 0.4))
                } else {
                    Text(contact.initials)
                        .font(.system(size: size * 0.4))
                        .fontWeight(.semibold)
                }
            }
            .frame(width: size, height: size)
        }
    }
}
