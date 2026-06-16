import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var daemon: VentDaemonManager
    @State private var currentStep = 0
    @State private var isInstalling = false

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            icon: "fanblades",
            title: "Welcome to Vent",
            description: "Vent controls your Mac's fans based on\ntemperature — quieter when cool,\nstronger when hot."
        ),
        OnboardingStep(
            icon: "gearshape.2",
            title: "Privileged Helper",
            description: "Vent needs a helper daemon with\nadmin access to control the fans.\nYou'll be asked for your password."
        ),
        OnboardingStep(
            icon: "arrow.triangle.2.circlepath",
            title: "Independent Updates",
            description: "The helper can be updated separately\nfrom the app — just click\n\"Update Helper\" in Settings anytime."
        ),
    ]

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
                if currentStep < steps.count - 1 {
                    Button("Next") {
                        currentStep += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)

                    Button("Skip") {
                        completeOnboarding()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
                } else {
                    if isInstalling {
                        ProgressView("Installing...")
                            .progressViewStyle(.linear)
                    } else {
                        Button("Install Helper") {
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
                        .keyboardShortcut(.defaultAction)

                        Button("Skip for now — I'll do it later") {
                            completeOnboarding()
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(width: 280, height: 340)
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
