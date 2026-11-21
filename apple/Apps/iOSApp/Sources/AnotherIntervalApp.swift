import SwiftUI
import Domain
import FeatureWorkoutRun

@main
struct AnotherIntervalApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Écran temporaire : lance l'écran de séance sur une séance de démo (la navigation viendra avec l'étape 3).
struct RootView: View {
    @State private var viewModel = RunViewModel(workout: DemoWorkout.breakfastClub)

    var body: some View {
        RunView(viewModel: viewModel)
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
}
