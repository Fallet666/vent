import SwiftUI
import AppKit

struct NativeSlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let isEnabled: Bool
    let onEditingChanged: ((Bool) -> Void)?

    init(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0,
        isEnabled: Bool = true,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.isEnabled = isEnabled
        self.onEditingChanged = onEditingChanged
    }

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider()
        slider.sliderType = .linear
        slider.controlSize = .regular
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.doubleValue = value
        slider.allowsTickMarkValuesOnly = false
        slider.isContinuous = true
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.sliderChanged(_:))
        slider.frame.size.height = 24

        if step > 0 {
            slider.numberOfTickMarks = 0
        }

        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        nsView.minValue = range.lowerBound
        nsView.maxValue = range.upperBound
        if !context.coordinator.isEditing {
            nsView.doubleValue = value
        }
        nsView.isEnabled = isEnabled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject {
        let parent: NativeSlider
        fileprivate(set) var isEditing = false
        private var debounceTimer: Timer?

        init(_ parent: NativeSlider) {
            self.parent = parent
        }

        @objc func sliderChanged(_ sender: NSSlider) {
            let rawValue = sender.doubleValue
            if parent.step > 0 {
                let steppedValue = round(rawValue / parent.step) * parent.step
                let clampedValue = min(max(steppedValue, parent.range.lowerBound), parent.range.upperBound)
                parent.value = clampedValue
            } else {
                parent.value = rawValue
            }

            if !isEditing {
                isEditing = true
                parent.onEditingChanged?(true)
            }

            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                guard let self, self.isEditing else { return }
                self.isEditing = false
                self.parent.onEditingChanged?(false)
            }
        }
    }
}
