import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var daemon: VentDaemonManager
    @AppStorage("loudFanNotificationEnabled") private var loudFanNotificationEnabled = false
    @State private var currentStep = 0
    @State private var isInstalling = false

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            icon: "fanblades",
            title: String(localized: "Welcome to Vent"),
            description: String(localized: "Vent controls your Mac's fans based on\ntemperature — quieter when cool,\nstronger when hot.")
        ),
        OnboardingStep(
            icon: "gearshape.2",
            title: String(localized: "Privileged Helper"),
            description: String(localized: "Vent needs a helper daemon with\nadmin access to control the fans.\nYou'll be asked for your password.")
        ),
        OnboardingStep(
            icon: "arrow.triangle.2.circlepath",
            title: String(localized: "Independent Updates"),
            description: String(localized: "The helper can be updated separately\nfrom the app — just click\n\"Update Helper\" in Settings anytime.")
        ),
        OnboardingStep(
            icon: "bell.badge",
            title: String(localized: "Loud Fan Alerts"),
            description: String(localized: "Get a notification when fans are\nrunning at high speed.")
        ),
    ]

    private var isInstallStep: Bool {
        currentStep == steps.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: steps[currentStep].icon)
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
                .symbolRenderingMode(.hierarchical)
                .frame(height: 50)

            Spacer().frame(height: 20)

            Text(steps[currentStep].title)
                .font(.title2.weight(.semibold))

            Spacer().frame(height: 8)

            Text(steps[currentStep].description)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if isInstallStep {
                Spacer().frame(height: 12)
                Toggle(String(localized: "Notify when fans are loud"), isOn: $loudFanNotificationEnabled)
                    .toggleStyle(.switch)
                    .font(.callout)
                Text(String(localized: "Useful for hearing impaired"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(currentStep == index ? Color.accentColor : Color.primary.opacity(0.2))
                        .frame(width: 7, height: 7)
                }
            }

            Spacer().frame(height: 16)

            VStack(spacing: 8) {
                if isInstallStep {
                    if isInstalling {
                        ProgressView(String(localized: "Installing..."))
                            .progressViewStyle(.linear)
                    } else {
                        Button(String(localized: "Install Helper")) {
                            isInstalling = true
                            daemon.installOrUpdateDaemon()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                daemon.refresh()
                                if daemon.daemonOnline {
                                    completeOnboarding()
                                }
                                isInstalling = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                        .keyboardShortcut(.defaultAction)

                        Button(String(localized: "Skip for now — I'll do it later")) {
                            completeOnboarding()
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                } else {
                    Button(String(localized: "Next")) {
                        currentStep += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .keyboardShortcut(.defaultAction)

                    Button(String(localized: "Skip")) {
                        completeOnboarding()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(width: 280, height: 380)
    }

    private func completeOnboarding() {
        daemon.hasCompletedOnboarding = true
    }
}

private struct OnboardingStep {
    let icon: String
    let title: String
    let description: String
}
