import SwiftUI
import Domain
import FeatureWorkoutRun

/// Historique des séances effectuées. Une séance « Every X » rouvre son récap set par set.
struct HistoryView: View {
    let store: LibraryStore
    @State private var selected: SessionRecord?

    var body: some View {
        NavigationStack {
            Group {
                if store.sessions.isEmpty {
                    ContentUnavailableView(
                        "Pas encore de séance",
                        systemImage: "clock",
                        description: Text("Tes séances terminées apparaîtront ici, avec le détail set par set.")
                    )
                } else {
                    List {
                        ForEach(store.sessions) { record in
                            Button { selected = record } label: { row(record) }
                        }
                        .onDelete { offsets in
                            let doomed = offsets.map { store.sessions[$0] }
                            Task { for record in doomed { await store.delete(record) } }
                        }
                    }
                }
            }
            .navigationTitle("Historique")
        }
        .fullScreenCover(item: $selected) { record in
            detail(record)
        }
    }

    private func row(_ record: SessionRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.workout.name).font(.headline).foregroundStyle(.primary)
                Text(record.startedAt.formatted(.dateTime.day().month().hour().minute()))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(HistoryView.resultText(for: record))
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func detail(_ record: SessionRecord) -> some View {
        if let summary = record.summary {
            EveryXSummaryView(
                workout: record.workout,
                summary: summary,
                shareText: ResultText.share(workout: record.workout, summary: summary),
                onClose: { selected = nil }
            )
        } else {
            VStack(spacing: 16) {
                Text(record.workout.name).font(.largeTitle.bold())
                Text(HistoryView.resultText(for: record)).font(.title2)
                Button("Fermer") { selected = nil }.buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    /// Résumé d'une ligne : « 4/6 sets » pour une séance Every X, sinon la durée.
    static func resultText(for record: SessionRecord) -> String {
        if let summary = record.summary { return "\(summary.completedCount)/\(summary.totalSets) sets" }
        return RunFormat.elapsed(record.duration)
    }
}
