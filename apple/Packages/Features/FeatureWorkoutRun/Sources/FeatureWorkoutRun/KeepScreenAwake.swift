import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension View {
    /// Empêche l'écran de se verrouiller pendant une séance (sinon les bips s'arrêtent avec l'app).
    func keepScreenAwake() -> some View {
        onAppear { setIdleTimerDisabled(true) }
            .onDisappear { setIdleTimerDisabled(false) }
    }
}

private func setIdleTimerDisabled(_ disabled: Bool) {
    #if canImport(UIKit)
    Task { @MainActor in
        UIApplication.shared.isIdleTimerDisabled = disabled
    }
    #endif
}
