import SwiftUI

struct GroupEditorSheet: View {
    enum Mode {
        case create
        case rename(String)
    }

    let mode: Mode
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2).bold()
            TextField("Group Name", text: $name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            if case .rename(let existing) = mode {
                name = existing
            }
        }
    }

    private var title: String {
        switch mode {
        case .create: return "New Group"
        case .rename: return "Rename Group"
        }
    }
}
