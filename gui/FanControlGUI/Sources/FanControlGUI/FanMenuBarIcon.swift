import AppKit
import CoreGraphics

enum FanMenuBarIcon {
    static func make(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else {
                return false
            }

            draw(in: context, rect: rect)
            return true
        }

        image.isTemplate = true
        return image
    }

    static func draw(in context: CGContext, rect: CGRect) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width / 18.0, y: rect.height / 18.0)

        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setFillColor(NSColor.white.cgColor)

        drawFrame(in: context)
        drawFan(in: context)

        context.restoreGState()
    }

    private static func drawFrame(in context: CGContext) {
        let framePath = CGMutablePath()

        framePath.addRoundedRect(
            in: CGRect(x: 0.55, y: 0.55, width: 16.9, height: 16.9),
            cornerWidth: 1.65,
            cornerHeight: 1.65
        )

        framePath.addEllipse(in: CGRect(x: 1.35, y: 1.35, width: 15.3, height: 15.3))

        addCornerCutout(to: framePath, topLeft: CGPoint(x: 2.15, y: 15.85), topRight: CGPoint(x: 4.15, y: 15.85), bottom: CGPoint(x: 2.15, y: 13.75))
        addCornerCutout(to: framePath, topLeft: CGPoint(x: 13.85, y: 15.85), topRight: CGPoint(x: 15.85, y: 15.85), bottom: CGPoint(x: 15.85, y: 13.75))
        addCornerCutout(to: framePath, topLeft: CGPoint(x: 2.15, y: 4.15), topRight: CGPoint(x: 2.15, y: 2.15), bottom: CGPoint(x: 4.15, y: 2.15))
        addCornerCutout(to: framePath, topLeft: CGPoint(x: 15.85, y: 4.15), topRight: CGPoint(x: 15.85, y: 2.15), bottom: CGPoint(x: 13.85, y: 2.15))

        context.addPath(framePath)
        context.fillPath(using: .evenOdd)
    }

    private static func addCornerCutout(to path: CGMutablePath, topLeft: CGPoint, topRight: CGPoint, bottom: CGPoint) {
        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottom)
        path.closeSubpath()
    }

    private static func drawFan(in context: CGContext) {
        let center = CGPoint(x: 9.0, y: 9.0)

        for index in 0..<4 {
            let blade = makeBladePath(center: center, angle: CGFloat(index) * .pi / 2.0 - .pi / 10.0)
            context.addPath(blade)
            context.fillPath()
        }

        context.addEllipse(in: CGRect(x: 7.35, y: 7.35, width: 3.3, height: 3.3))
        context.fillPath()
    }

    private static func makeBladePath(center: CGPoint, angle: CGFloat) -> CGPath {
        let path = CGMutablePath()
        var left: [CGPoint] = []
        var right: [CGPoint] = []

        let innerRadius: CGFloat = 2.35
        let outerRadius: CGFloat = 6.85
        let steps = 36

        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let radius = innerRadius + (outerRadius - innerRadius) * t
            let theta = angle + degrees(10.0 + 43.0 * t)
            let width = CGFloat(0.18 + 0.78 * sin(Double.pi * Double(t))) * 1.35

            let x = center.x + radius * cos(theta)
            let y = center.y + radius * sin(theta)

            let normalX = -sin(theta)
            let normalY = cos(theta)

            left.append(CGPoint(x: x + normalX * width, y: y + normalY * width))
            right.append(CGPoint(x: x - normalX * width, y: y - normalY * width))
        }

        if let first = left.first {
            path.move(to: first)
        }

        for point in left.dropFirst() {
            path.addLine(to: point)
        }

        for point in right.reversed() {
            path.addLine(to: point)
        }

        path.closeSubpath()
        return path
    }

    private static func degrees(_ value: CGFloat) -> CGFloat {
        value * .pi / 180.0
    }
}
