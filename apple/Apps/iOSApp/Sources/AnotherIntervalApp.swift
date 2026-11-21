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

/// Écran temporaire : séances de démo + import par photo (la vraie navigation et le stockage viennent ensuite).
struct RootView: View {
    @State private var selected: Workout?
    @State private var imported: [Workout] = []
    @State private var showImport = false
    @State private var importModel = PhotoImportViewModel(
        service: PhotoWorkoutImportService(client: AnthropicImportClient(apiKey: AppConfig.anthropicKey))
    )

    var body: some View {
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
                if !imported.isEmpty {
                    Section("Importées") { rows(imported) }
                }
                Section("Séances de démo") { rows(DemoWorkout.all) }
            }
            .navigationTitle("Another Interval")
        }
        .sheet(isPresented: $showImport) {
            PhotoImportView(
                viewModel: importModel,
                onStart: { workout in
                    imported.insert(workout, at: 0)
                    showImport = false
                    selected = workout
                },
                onClose: { showImport = false }
            )
        }
        .fullScreenCover(item: $selected) { workout in
            RunHost(workout: workout) { selected = nil }
        }
    }

    private func rows(_ workouts: [Workout]) -> some View {
        ForEach(workouts) { workout in
            Button {
                selected = workout
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name).font(.headline)
                    Text(workout.format.rawValue.uppercased())
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Garde le ViewModel de la séance en vie pendant toute la présentation.
struct RunHost: View {
    @State private var viewModel: RunViewModel
    let onClose: () -> Void

    init(workout: Workout, onClose: @escaping () -> Void) {
        _viewModel = State(initialValue: RunViewModel(workout: workout, guidance: SystemGuidanceOutput()))
        self.onClose = onClose
    }

    var body: some View {
        RunView(viewModel: viewModel, onClose: onClose)
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

    static let all: [Workout] = [breakfastClub, emom, amrap, fran]
}
