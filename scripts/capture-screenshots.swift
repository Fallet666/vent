import AppKit
import SwiftUI
import ScreenCaptureKit

// Compiled alongside the real GUI sources by capture-screenshots.sh.
// This entry point never starts AppDelegate or connects to a hardware helper.
final class CaptureWindow: NSWindow {
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
}

@main
struct CaptureScreenshots {
    @MainActor static func main() async throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let output = CommandLine.arguments[1]
        defer { UserDefaults.standard.removePersistentDomain(forName: "dev.vent.documentation-capture") }
        let manager = VentDaemonManager.shared
        manager.isRefreshing = true // Block ContentView.onAppear's live refresh.
        manager.hasCompletedOnboarding = true
        manager.daemonOnline = true
        manager.bundledVersion = "1.3.7"
        manager.helperVersion = "1.3.7"
        manager.statusMessage = "Ready"
        manager.config = VentDaemonConfig(minTargetTemperature: 20, maxTargetTemperature: 95,
            defaultTargetTemperature: 55, minUsableTemperature: 20, maxUsableTemperature: 130)
        for dark in [false, true] {
            let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
            app.appearance = appearance
            for scenario in ["temperature", "noise", "manual", "auto"] {
                manager.controlMode = scenario == "manual" ? .manualRPM : scenario == "auto" ? .auto : .autoTemp
                manager.targetTemperature = 55
                manager.averageTemperature = scenario == "noise" ? 76 : 58
                manager.autoTemperatureRPM = scenario == "noise" ? 5100 : 2800
                manager.separateFans = scenario == "manual"
                let rpm = scenario == "noise" ? 5100 : 2800
                manager.fans = (0..<2).map { FanState(index: $0, rpm: rpm, currentRPM: rpm,
                    minRPM: 1200, maxRPM: 6000, manualMode: scenario != "auto") }
                manager.selectedProfileID = manager.profiles.first { $0.name == (scenario == "auto" ? "Quiet" : "Gaming") }?.id
                let view = ContentView().environmentObject(manager)
                    .environment(\.colorScheme, dark ? .dark : .light)
                    .environment(\.controlActiveState, .key)
                    .frame(width: 320)
                    .transaction { $0.animation = nil; $0.disablesAnimations = true }
                let hosting = NSHostingView(rootView: view)
                hosting.appearance = appearance
                // Show the sample window so the system compositor renders glass layers.
                // A real window also supplies the correct Retina backing scale.
                let window = CaptureWindow(contentRect: NSRect(x: 40, y: 40, width: 320, height: 400),
                    styleMask: .borderless, backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.isOpaque = false
                window.backgroundColor = .clear
                window.hasShadow = false
                window.appearance = appearance
                window.contentView = hosting
                window.orderFrontRegardless()
                try await Task.sleep(for: .seconds(1))
                let height = ceil(hosting.fittingSize.height)
                hosting.frame = NSRect(x: 0, y: 0, width: 320, height: height)
                window.setContentSize(NSSize(width: 320, height: height))
                hosting.layoutSubtreeIfNeeded()
                window.displayIfNeeded()
                // Capture our own composited window, including glass/material layers.
                // currentProcess exposes only this process's content, without TCC access
                // to the user's other windows or desktop.
                try await Task.sleep(for: .milliseconds(250))
                let content = try await SCShareableContent.currentProcess
                guard let surface = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) }) else {
                    throw NSError(domain: "VentCapture", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Capture window is unavailable"])
                }
                let filter = SCContentFilter(desktopIndependentWindow: surface)
                let configuration = SCStreamConfiguration()
                configuration.width = 640
                configuration.height = Int(height * 2)
                configuration.showsCursor = false
                configuration.ignoreShadowsSingleWindow = true
                configuration.captureResolution = .best
                let rendered = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
                let bitmap = NSBitmapImageRep(cgImage: rendered)
                let url = URL(fileURLWithPath: output).appendingPathComponent("\(scenario)-\(dark ? "dark" : "light").png")
                try bitmap.representation(using: .png, properties: [:])!.write(to: url)
                window.orderOut(nil)
                print("Rendered \(url.lastPathComponent): 640 × \(Int(height * 2))")
            }
        }
    }
}
