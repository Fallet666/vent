import AppKit
import VentGUIModels

@MainActor
func launchApp() {
    AppDelegate.start()
}

MainActor.assumeIsolated {
    launchApp()
}
