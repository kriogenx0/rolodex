import SwiftUI

struct SmartGroupEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: ContactsViewModel
    @State var smartGroup: SmartGroup
    let onSave: (SmartGroup) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Smart Group").font(.title2).bold()

            Form {
                TextField("Name", text: $smartGroup.name)

                Picker("Match", selection: $smartGroup.matchType) {
                    ForEach(MatchType.allCases) { type in
                        Text("\(type.rawValue) of the following").tag(type)
                    }
                }
                .pickerStyle(.segmented)

                ForEach($smartGroup.rules) { $rule in
                    HStack {
                        Picker("", selection: $rule.field) {
                            ForEach(RuleField.allCases) { field in
                                Text(field.rawValue).tag(field)
                            }
                        }
                        .frame(width: 110)
                        .labelsHidden()

                        Picker("", selection: $rule.op) {
                            ForEach(RuleOperator.allCases) { op in
                                Text(op.rawValue).tag(op)
                            }
                        }
                        .frame(width: 110)
                        .labelsHidden()

                        if rule.op != .isSet {
                            if rule.field.usesFixedValues {
                                Picker("", selection: $rule.value) {
                                    ForEach(rule.field.fixedValues, id: \.self) { value in
                                        Text(value).tag(value)
                                    }
                                }
                                .labelsHidden()
                                .onAppear {
                                    if rule.value.isEmpty {
                                        rule.value = rule.field.fixedValues.first ?? ""
                                    }
                                }
                            } else {
                                TextField("Value", text: $rule.value)
                            }
                        }

                        Button {
                            smartGroup.rules.removeAll { $0.id == rule.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    smartGroup.rules.append(SmartGroupRule())
                } label: {
                    Label("Add Rule", systemImage: "plus.circle")
                }

                Toggle("Hide these contacts from All Contacts", isOn: $smartGroup.isHiddenFromAllContacts)

                LabeledContent("Matches") {
                    Text("\(viewModel.evaluate(smartGroup: smartGroup).count) contacts")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    onSave(smartGroup)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(smartGroup.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 560, height: 480)
    }
}
