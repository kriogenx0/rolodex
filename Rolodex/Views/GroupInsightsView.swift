import Charts
import Contacts
import SwiftUI

struct GroupInsightsView: View {
    @EnvironmentObject var viewModel: ContactsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Group Insights")
                    .font(.largeTitle.bold())

                statsSection
                noGroupSection
                emptyGroupsSection
                overlapSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Insights")
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contacts per Group").font(.headline)
            if viewModel.groupStats.isEmpty {
                Text("No groups yet.").foregroundStyle(.secondary)
            } else {
                Chart(Array(viewModel.groupStats.prefix(12))) { stat in
                    BarMark(
                        x: .value("Contacts", stat.count),
                        y: .value("Group", stat.name)
                    )
                    .foregroundStyle(by: .value("Group", stat.name))
                }
                .frame(height: CGFloat(min(viewModel.groupStats.count, 12)) * 28 + 20)
                .chartLegend(.hidden)
            }
        }
    }

    private var noGroupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Contacts Without a Group").font(.headline)
                Spacer()
                Text("\(viewModel.contactsWithoutGroup.count)")
                    .foregroundStyle(.secondary)
            }
            if viewModel.contactsWithoutGroup.isEmpty {
                Text("Every contact belongs to at least one group.").foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.contactsWithoutGroup.prefix(8), id: \.identifier) { contact in
                    Text(contact.displayName)
                }
                if viewModel.contactsWithoutGroup.count > 8 {
                    Text("and \(viewModel.contactsWithoutGroup.count - 8) more…")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var emptyGroupsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Empty Groups").font(.headline)
            if viewModel.emptyGroups.isEmpty {
                Text("No empty groups.").foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.emptyGroups, id: \.identifier) { group in
                    HStack {
                        Text(group.name)
                        Spacer()
                        Button("Delete", role: .destructive) {
                            viewModel.delete(group: group)
                        }
                        .buttonStyle(.link)
                    }
                }
            }
        }
    }

    private var overlapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overlapping Groups").font(.headline)
            Text("Groups that share at least half their members — good candidates to merge.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if viewModel.overlappingGroupPairs.isEmpty {
                Text("No significant overlaps found.").foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.overlappingGroupPairs) { pair in
                    HStack {
                        Text("\(pair.firstName) ↔ \(pair.secondName)")
                        Spacer()
                        Text("\(pair.overlapCount) shared · \(Int(pair.overlapFraction * 100))%")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
