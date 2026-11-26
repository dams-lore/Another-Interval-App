import SwiftUI
import Domain
import FeatureWorkoutRun
import FeaturePhotoImport
import Platform
import Backend
import DataLayer

@main
struct AnotherIntervalApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Clé de développement lue dans Info.plist (remplie depuis Config/Secrets.xcconfig, jamais commitée).
enum AppConfig {
    static var anthropicKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "AnthropicAPIKey") as? String) ?? ""
    }
}

/// Écran principal : mes séances (démo + importées + enregistrées) et l'historique.
struct RootView: View {
    @State private var store: LibraryStore
    @State private var selected: Workout?
    @State private var showImport = false
    @State private var importModel = PhotoImportViewModel(
        service: PhotoWorkoutImportService(client: AnthropicImportClient(apiKey: AppConfig.anthropicKey))
    )

    init(store: LibraryStore = .live()) {
        _store = State(initialValue: store)
    }

    var body: some View {
        TabView {
            workoutsTab
                .tabItem { Label("Séances", systemImage: "list.bullet") }
            HistoryView(store: store)
                .tabItem { Label("Historique", systemImage: "clock") }
        }
        .task { await store.load() }
        .sheet(isPresented: $showImport) {
            PhotoImportView(
                viewModel: importModel,
                onStart: { workout in
                    Task { await store.save(workout) }
                    showImport = false
                    selected = workout
                },
                onSave: { workout in
                    Task { await store.save(workout) }
                    showImport = false
                },
                onClose: { showImport = false }
            )
        }
        .fullScreenCover(item: $selected) { workout in
            RunHost(
                workout: workout,
                onSessionFinished: { record in Task { await store.record(record) } },
                onClose: { selected = nil }
            )
        }
    }

    private var workoutsTab: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        importModel.reset()
                        showImport = true
                    } label: {
                        Label("Importer une séance par photo", systemImage: "camera.viewfinder")
                            .font(.headline)
                    }
                }
                Section("Mes séances") {
                    ForEach(store.workouts) { workout in
                        Button { selected = workout } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.name).font(.headline).foregroundStyle(.primary)
                                Text(Self.subtitle(of: workout)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        let doomed = offsets.map { store.workouts[$0] }
                        Task { for workout in doomed { await store.delete(workout) } }
                    }
                }
            }
            .navigationTitle("Another Interval")
        }
    }

    /// Une ligne de description : « Every 5:00 × 6 · 4 étapes », « AMRAP 12 min »…
    static func subtitle(of workout: Workout) -> String {
        switch workout.format {
        case .emom:
            let interval = RunFormat.short(workout.intervalSeconds ?? 60)
            return "Every \(interval) × \(workout.rounds ?? 1) · \(workout.steps.count) étapes"
        case .amrap:
            return "AMRAP \(Int((workout.capTime ?? 0) / 60)) min"
        case .forTime:
            return "For Time" + (workout.capTime.map { " · cap \(Int($0 / 60)) min" } ?? "")
        case .intervals:
            return "Fractionné · \(workout.rounds ?? 1) tours · \(workout.steps.count) blocs"
        }
    }
}

/// Garde le ViewModel de la séance en vie pendant toute la présentation.
/// Les séances « Every X × N » (EMOM) ouvrent leur parcours dédié, les autres l'écran de séance classique.
struct RunHost: View {
    @State private var runModel: RunViewModel
    @State private var everyModel: EveryXViewModel
    private let isEveryX: Bool
    let onClose: () -> Void

    init(workout: Workout, onSessionFinished: @escaping @MainActor (SessionRecord) -> Void, onClose: @escaping () -> Void) {
        _runModel = State(initialValue: RunViewModel(workout: workout, guidance: SystemGuidanceOutput(), onFinished: onSessionFinished))
        _everyModel = State(initialValue: EveryXViewModel(workout: workout, guidance: SystemGuidanceOutput(), onFinished: onSessionFinished))
        isEveryX = workout.format == .emom && !workout.steps.isEmpty
        self.onClose = onClose
    }

    var body: some View {
        if isEveryX {
            EveryXView(model: everyModel, onClose: onClose)
        } else {
            RunView(viewModel: runModel, onClose: onClose)
        }
    }
}

enum DemoWorkout {
    static let breakfastClub = Workout(
        name: "Breakfast Club",
        format: .intervals,
        steps: [
            Step(type: .time, movement: "400m Run", value: 90),
            Step(type: .time, movement: "Rest", value: 30),
        ],
        rounds: 4
    )

    static let emom = Workout(
        name: "EMOM 10 — Burpees",
        format: .emom,
        steps: [Step(type: .reps, movement: "10 Burpees", value: 10)],
        rounds: 10
    )

    static let amrap = Workout(
        name: "Cindy (AMRAP 12)",
        format: .amrap,
        steps: [
            Step(type: .reps, movement: "5 Pull-ups", value: 5),
            Step(type: .reps, movement: "10 Push-ups", value: 10),
            Step(type: .reps, movement: "15 Air squats", value: 15),
        ],
        capTime: 720
    )

    static let fran = Workout(
        name: "Fran",
        format: .forTime,
        steps: [
            Step(type: .reps, movement: "21-15-9 Thrusters", value: 45),
            Step(type: .reps, movement: "21-15-9 Pull-ups", value: 45),
        ],
        capTime: 600
    )

    /// Séance réelle de Dams (« Every 5:00 x 6 sets ») : intervalles de 5 minutes, tâches à enchaîner dans chacun.
    static let darkZone = Workout(
        name: "EMF RX - DARK ZONE Burpees And Row",
        format: .emom,
        steps: [
            Step(type: .reps, movement: "Row", value: 20, unit: "cal", notes: "H/F : 20/16"),
            Step(type: .reps, movement: "Burpees Over Row", value: 15),
            Step(type: .reps, movement: "Row", value: 20, unit: "cal", notes: "H/F : 20/16"),
            Step(type: .reps, movement: "Burpees Over Row", value: 15),
        ],
        rounds: 6,
        intervalSeconds: 300
    )

    static let all: [Workout] = [darkZone, breakfastClub, emom, amrap, fran]
}
