import SwiftUI
import AppKit

struct NativeSlider: NSViewRepresentable {
    @Binding var value: Double
    var range: ClosedRange<Double> { scale.range }
    let scale: SliderScale
    let isEnabled: Bool
    let onEditingChanged: ((Bool) -> Void)?

    init(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        ticks: [Double],
        isEnabled: Bool = true,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.scale = SliderScale(range: range, step: step, ticks: ticks)
        self.isEnabled = isEnabled
        self.onEditingChanged = onEditingChanged
    }

    func makeNSView(context: Context) -> TrackingSlider {
        let slider = TrackingSlider()
        slider.sliderType = .linear
        slider.controlSize = .regular
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.doubleValue = value
        slider.allowsTickMarkValuesOnly = false
        slider.isContinuous = true
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.sliderChanged(_:))

        slider.ticks = scale.ticks

        return slider
    }

    func updateNSView(_ nsView: TrackingSlider, context: Context) {
        context.coordinator.parent = self
        nsView.minValue = range.lowerBound
        nsView.maxValue = range.upperBound
        if !context.coordinator.isEditing {
            nsView.doubleValue = value
        }
        nsView.isEnabled = isEnabled
        nsView.ticks = scale.ticks
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject {
        var parent: NativeSlider
        fileprivate(set) var isEditing = false
        private var debounceTimer: Timer?

        init(_ parent: NativeSlider) {
            self.parent = parent
        }

        deinit {
            debounceTimer?.invalidate()
        }

        @objc func sliderChanged(_ sender: NSSlider) {
            if !isEditing {
                isEditing = true
                parent.onEditingChanged?(true)
            }
            let value = parent.scale.selection(
                at: sender.doubleValue, magnetize: (sender as? TrackingSlider)?.isTrackingMouse == true
            )
            sender.doubleValue = value
            parent.value = value

            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                guard let self, self.isEditing else { return }
                self.isEditing = false
                self.parent.onEditingChanged?(false)
            }
        }
    }
}

final class TrackingSlider: NSSlider {
    private(set) var isTrackingMouse = false
    var ticks: [Double] = [] {
        didSet {
            if oldValue != ticks { needsDisplay = true }
        }
    }

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(width: size.width, height: max(28, size.height))
    }

    override func mouseDown(with event: NSEvent) {
        isTrackingMouse = true
        defer { isTrackingMouse = false }
        super.mouseDown(with: event)
    }

    func tickRects() -> [NSRect] {
        guard let cell = cell as? NSSliderCell, maxValue > minValue else { return [] }
        let track = cell.trackRect.insetBy(dx: cell.knobThickness / 2, dy: 0)
        let y = isFlipped ? bounds.maxY - 4 : bounds.minY + 2
        return ticks.map { tick in
            let fraction = (tick - minValue) / (maxValue - minValue)
            let x = track.minX + track.width * fraction
            return NSRect(x: x - 0.5, y: y, width: 1, height: 2)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        (isEnabled ? NSColor.secondaryLabelColor : NSColor.disabledControlTextColor).setFill()
        for rect in tickRects() {
            NSBezierPath(rect: rect).fill()
        }
    }
}

struct SliderScale {
    let range: ClosedRange<Double>
    let step: Double
    let ticks: [Double]

    static func multiples(of interval: Double, in range: ClosedRange<Double>) -> [Double] {
        let first = ceil(range.lowerBound / interval) * interval
        guard first <= range.upperBound else { return [] }
        return Array(stride(from: first, through: range.upperBound, by: interval))
    }

    func selection(at raw: Double, magnetize: Bool) -> Double {
        if raw <= range.lowerBound { return range.lowerBound }
        if raw >= range.upperBound { return range.upperBound }
        if magnetize, let nearest = ticks.min(by: { abs(raw - $0) < abs(raw - $1) }),
           abs(raw - nearest) <= step * 1.25 {
            return nearest
        }
        return min(max((raw / step).rounded() * step, range.lowerBound), range.upperBound)
    }
}
