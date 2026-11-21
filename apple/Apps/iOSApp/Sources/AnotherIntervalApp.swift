import SwiftUI
import DesignSystem

@main
struct AnotherIntervalApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Another Interval")
                .font(.largeTitle.bold())
            Text(DesignSystem.moduleName)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
