import SwiftUI
import Domain
import FeatureWorkoutRun
import Platform

@main
struct AnotherIntervalApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Écran temporaire : liste de séances de démo pour essayer tous les formats
/// (la vraie navigation, l'éditeur et l'import photo viennent ensuite).
struct RootView: View {
    @State private var selected: Workout?

    var body: some View {
        NavigationStack {
            List(DemoWorkout.all) { workout in
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
            .navigationTitle("Séances de démo")
        }
        .fullScreenCover(item: $selected) { workout in
            RunHost(workout: workout) { selected = nil }
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
