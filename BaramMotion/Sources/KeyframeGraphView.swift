import AppKit

protocol KeyframeGraphViewDelegate: AnyObject {
    func keyframeGraph(_ graph: KeyframeGraphView, didSelect property: MainViewController.AnimatedProperty, frame: Int)
    func keyframeGraph(_ graph: KeyframeGraphView, didMove layerID: UUID, property: MainViewController.AnimatedProperty, fromFrame: Int, toFrame: Int, value: CGFloat?)
    func keyframeGraph(_ graph: KeyframeGraphView, didChangeEasingAt layerID: UUID, property: MainViewController.AnimatedProperty, frame: Int, easing: MainViewController.CubicBezier)
    func keyframeGraph(_ graph: KeyframeGraphView, didAddKeyframeFor property: MainViewController.AnimatedProperty, at frame: Int)
    func keyframeGraph(_ graph: KeyframeGraphView, didDeleteKeyframeAt layerID: UUID, property: MainViewController.AnimatedProperty, frame: Int)
}

final class KeyframeGraphView: NSView {
    weak var delegate: KeyframeGraphViewDelegate?
    var layers: [MainViewController.LayerModel] = [] { didSet { needsDisplay = true } }
    var selectedLayerID: UUID? { didSet { needsDisplay = true } }
    var currentFrame: Int = 0 { didSet { needsDisplay = true } }
    var selectedProperty: MainViewController.AnimatedProperty? { didSet { needsDisplay = true } }
    var selectedKeyframeFrame: Int? { didSet { needsDisplay = true } }

    private let leftAxisWidth: CGFloat = 44
    private let topAxisHeight: CGFloat = 28
    private var timeScale: CGFloat = 4.0
    private var valueScale: CGFloat = 1.0
    private var timeOrigin: CGFloat = 0
    private var valueCenter: CGFloat = 0
    private var drag: DragState?
    private var handleDrag: HandleDragState?
    private var magnificationStartX: CGFloat = 1
    private var magnificationStartY: CGFloat = 1

    private struct CurvePoint {
        let layerID: UUID
        let property: MainViewController.AnimatedProperty
        let frame: Int
        let value: CGFloat
        let color: NSColor
    }

    private struct DragState {
        let point: CurvePoint
        let startPoint: CGPoint
        let startFrame: Int
        let startValue: CGFloat
    }

    private struct HandleDragState {
        let layerID: UUID
        let property: MainViewController.AnimatedProperty
        let frame: Int
        let handleIndex: Int
        let startHandle: CGPoint
        let startMouse: CGPoint
        let frameRangePixels: CGFloat
        let valueRangePixels: CGFloat
    }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // The graph sits directly on the parent floating panel's Liquid Glass surface.
        // Do not draw another panel/background here; that creates a visually nested frame.
        guard let id = selectedLayerID, let layer = layers.first(where: { $0.id == id }) else {
            valueCenter = 0
            valueScale = 1
            drawAxes();
            NSString(string: "レイヤーを選択してください").draw(at: NSPoint(x: 16, y: 42), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor])
            return
        }
        updateValueViewport(for: layer)
        drawAxes()
        let properties = selectedProperty.map { [$0] } ?? MainViewController.AnimatedProperty.allCases
        for property in properties {
            drawCurve(layer: layer, property: property)
        }
        drawPlayhead()
        drawSelection()
    }

    private func drawAxes() {
        NSColor.separatorColor.setStroke()
        let axis = NSBezierPath()
        axis.move(to: NSPoint(x: leftAxisWidth, y: topAxisHeight)); axis.line(to: NSPoint(x: leftAxisWidth, y: bounds.height));
        axis.move(to: NSPoint(x: leftAxisWidth, y: topAxisHeight)); axis.line(to: NSPoint(x: bounds.width, y: topAxisHeight));
        axis.lineWidth = 1; axis.stroke()

        let visibleFrames = max(10, Int((bounds.width - leftAxisWidth) / max(0.5, timeScale)))
        let step = visibleFrames > 180 ? 30 : visibleFrames > 90 ? 15 : visibleFrames > 45 ? 5 : 1
        let start = max(0, Int(timeOrigin))
        let end = start + visibleFrames + step
        for frame in stride(from: start - start % step, through: end, by: step) {
            let x = frameToX(frame)
            NSColor.separatorColor.withAlphaComponent(0.28).setStroke()
            let path = NSBezierPath(); path.move(to: NSPoint(x: x, y: topAxisHeight)); path.line(to: NSPoint(x: x, y: bounds.height)); path.lineWidth = 0.5; path.stroke()
            NSString(string: "\(frame)").draw(at: NSPoint(x: x + 3, y: 7), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular), .foregroundColor: NSColor.tertiaryLabelColor])
        }

        let visibleValueHeight = max(40, bounds.height - topAxisHeight - 12)
        let rawStep = 50 / max(0.01, valueScale)
        let magnitude = pow(10, floor(log10(max(0.0001, rawStep))))
        let normalized = rawStep / magnitude
        let multiplier: CGFloat = normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10
        let valueStep = magnitude * multiplier
        let firstValue = floor((valueCenter - (bounds.height - topAxisHeight) * 0.5 / max(0.01, valueScale)) / valueStep) * valueStep
        var v = firstValue
        var safety = 0
        while v <= valueCenter + visibleValueHeight / max(0.01, valueScale) && safety < 100 {
            let y = valueToY(v)
            if y >= topAxisHeight && y <= bounds.height {
                NSColor.separatorColor.withAlphaComponent(0.18).setStroke()
                let path = NSBezierPath(); path.move(to: NSPoint(x: leftAxisWidth, y: y)); path.line(to: NSPoint(x: bounds.width, y: y)); path.lineWidth = 0.5; path.stroke()
                NSString(string: formatGraphValue(v)).draw(at: NSPoint(x: 4, y: y - 7), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular), .foregroundColor: NSColor.tertiaryLabelColor])
            }
            v += valueStep
            safety += 1
        }
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: NSColor.secondaryLabelColor]
        NSString(string: "値").draw(at: NSPoint(x: 8, y: topAxisHeight + 5), withAttributes: titleAttrs)
        NSString(string: "フレーム").draw(at: NSPoint(x: bounds.width - 56, y: 7), withAttributes: titleAttrs)
    }

    private func drawCurve(layer: MainViewController.LayerModel, property: MainViewController.AnimatedProperty) {
        let keys = layer.propertyKeyframes.filter { $0.property == property }.sorted { $0.frame < $1.frame }
        guard !keys.isEmpty else { return }
        let color = colorFor(property)
        var coords: [CGPoint] = []
        for key in keys {
            let value = graphValue(for: key, property: property)
            coords.append(CGPoint(x: frameToX(key.frame), y: valueToY(value)))
        }
        if coords.count > 1 {
            drawBezierCurve(points: coords, keys: keys, color: color)
        }
        for (index, key) in keys.enumerated() {
            let point = coords[index]
            drawDiamond(at: point, filled: true, color: color, selected: selectedProperty == property && selectedKeyframeFrame == key.frame)
            if index < keys.count - 1 {
                let nextPoint = coords[index + 1]
                drawHandleLines(layer: layer, property: property, key: key, nextKey: keys[index + 1], point: point, nextPoint: nextPoint, color: color)
                drawHandlePoints(layer: layer, property: property, key: key, nextKey: keys[index + 1], point: point, nextPoint: nextPoint, color: color)
            } else {
                drawHandlePoints(layer: layer, property: property, key: key, nextKey: nil, point: point, nextPoint: point, color: color)
            }
        }
        let label = property.rawValue
        let p = coords.last ?? .zero
        if p.x > leftAxisWidth + 4 && p.x < bounds.width - 4 {
            NSString(string: label).draw(at: NSPoint(x: p.x + 7, y: p.y - 7), withAttributes: [.font: NSFont.systemFont(ofSize: 9, weight: .medium), .foregroundColor: color])
        }
    }

    private func drawBezierCurve(points: [CGPoint], keys: [MainViewController.PropertyKeyframe], color: NSColor) {
        guard points.count >= 2 else { return }
        let path = NSBezierPath()
        path.move(to: points[0])
        for i in 0..<points.count - 1 {
            let p0 = points[i]
            let p3 = points[i + 1]
            let cp1 = graphHandlePoint(key: keys[i], nextKey: keys[i + 1], point: p0, nextPoint: p3, isStart: true)
            let cp2 = graphHandlePoint(key: keys[i], nextKey: keys[i + 1], point: p0, nextPoint: p3, isStart: false)
            path.curve(to: p3, controlPoint1: cp1, controlPoint2: cp2)
        }
        color.withAlphaComponent(0.72).setStroke()
        path.lineWidth = 1.4
        path.stroke()
    }

    private func graphHandlePoint(key: MainViewController.PropertyKeyframe, nextKey: MainViewController.PropertyKeyframe, point: CGPoint, nextPoint: CGPoint, isStart: Bool) -> CGPoint {
        let easing = isStart ? key.easing.cp1 : key.easing.cp2
        let dx = max(1, CGFloat(nextKey.frame - key.frame)) * timeScale
        let dy = nextPoint.y - point.y
        return CGPoint(
            x: point.x + easing.x * dx,
            y: point.y + easing.y * dy
        )
    }

    private func drawHandleLines(layer: MainViewController.LayerModel, property: MainViewController.AnimatedProperty, key: MainViewController.PropertyKeyframe, nextKey: MainViewController.PropertyKeyframe, point: CGPoint, nextPoint: CGPoint, color: NSColor) {
        let cp1 = graphHandlePoint(key: key, nextKey: nextKey, point: point, nextPoint: nextPoint, isStart: true)
        let cp2 = graphHandlePoint(key: key, nextKey: nextKey, point: point, nextPoint: nextPoint, isStart: false)

        let path1 = NSBezierPath()
        path1.move(to: point)
        path1.line(to: cp1)
        color.withAlphaComponent(0.35).setStroke()
        path1.lineWidth = 0.8
        path1.setLineDash([4, 3], count: 2, phase: 0)
        path1.stroke()

        let path2 = NSBezierPath()
        path2.move(to: nextPoint)
        path2.line(to: cp2)
        color.withAlphaComponent(0.35).setStroke()
        path2.lineWidth = 0.8
        path2.setLineDash([4, 3], count: 2, phase: 0)
        path2.stroke()
    }

    private func drawHandlePoints(layer: MainViewController.LayerModel, property: MainViewController.AnimatedProperty, key: MainViewController.PropertyKeyframe, nextKey: MainViewController.PropertyKeyframe?, point: CGPoint, nextPoint: CGPoint, color: NSColor) {
        guard let nextKey = nextKey else { return }
        let cp1 = graphHandlePoint(key: key, nextKey: nextKey, point: point, nextPoint: nextPoint, isStart: true)
        let cp2 = graphHandlePoint(key: key, nextKey: nextKey, point: point, nextPoint: nextPoint, isStart: false)

        drawHandle(at: cp1, label: "cp1", selected: false, color: color)
        drawHandle(at: cp2, label: "cp2", selected: false, color: color)
    }

    private func drawHandle(at point: CGPoint, label: String, selected: Bool, color: NSColor) {
        let r: CGFloat = 6
        let p = NSBezierPath(ovalIn: NSRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
        if selected {
            NSColor.white.setFill()
            p.fill()
            color.setStroke()
            p.lineWidth = 2
            p.stroke()
        } else {
            color.withAlphaComponent(0.7).setFill()
            p.fill()
            color.setStroke()
            p.lineWidth = 1
            p.stroke()
        }
        NSString(string: label).draw(at: NSPoint(x: point.x + r + 3, y: point.y - 7), withAttributes: [.font: NSFont.systemFont(ofSize: 7), .foregroundColor: color])
    }

    private func drawDiamond(at point: CGPoint, filled: Bool, color: NSColor, selected: Bool) {
        let r: CGFloat = selected ? 6 : 5
        let p = NSBezierPath(); p.move(to: NSPoint(x: point.x, y: point.y-r)); p.line(to: NSPoint(x: point.x+r, y: point.y)); p.line(to: NSPoint(x: point.x, y: point.y+r)); p.line(to: NSPoint(x: point.x-r, y: point.y)); p.close()
        color.setFill(); p.fill(); if selected { NSColor.white.setStroke(); p.lineWidth = 1; p.stroke() }
    }

    private func drawPlayhead() {
        let x = frameToX(currentFrame)
        NSColor.controlAccentColor.setStroke(); let path = NSBezierPath(); path.move(to: NSPoint(x: x, y: 0)); path.line(to: NSPoint(x: x, y: bounds.height)); path.lineWidth = 1.5; path.stroke()
        let knob = NSBezierPath(); knob.move(to: NSPoint(x: x - 6, y: 0)); knob.line(to: NSPoint(x: x + 6, y: 0)); knob.line(to: NSPoint(x: x, y: 10)); knob.close(); NSColor.controlAccentColor.setFill(); knob.fill()
    }

    private func drawSelection() {
        guard let property = selectedProperty, let frame = selectedKeyframeFrame else { return }
        NSString(string: "\(property.rawValue) • frame \(frame)").draw(at: NSPoint(x: leftAxisWidth + 8, y: bounds.height - 20), withAttributes: [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.tertiaryLabelColor])
    }

    private func colorFor(_ property: MainViewController.AnimatedProperty) -> NSColor {
        switch property {
        case .x: return .systemRed
        case .y: return .systemGreen
        case .width: return .systemBlue
        case .height: return .systemOrange
        case .scaleX: return .systemIndigo
        case .scaleY: return .systemBrown
        case .rotation: return .systemGray
        case .opacity: return .systemPink
        case .borderWidth: return .systemBrown
        case .borderColor: return .systemGray
        case .cornerRadius: return .systemPurple
        case .color: return .systemTeal
        case .text: return .systemPink
        case .font: return .systemMint
        case .isOn: return .systemYellow
        }
    }

    private func graphValue(for key: MainViewController.PropertyKeyframe, property: MainViewController.AnimatedProperty) -> CGFloat {
        switch property {
        case .x,.y,.width,.height,.scaleX,.scaleY,.rotation,.opacity,.borderWidth,.cornerRadius: return key.scalar
        case .isOn: return key.boolValue ? 1 : 0
        case .text, .font, .borderColor: return 0
        case .color: return key.scalar
        }
    }

    private func updateValueViewport(for layer: MainViewController.LayerModel) {
        let property = selectedProperty
        guard let property else {
            valueCenter = 0
            valueScale = 1
            return
        }

        let values: [CGFloat]
        if property.isNumeric {
            let keyValues = layer.propertyKeyframes.filter { $0.property == property }.map { graphValue(for: $0, property: property) }
            let baseValue: CGFloat?
            switch property {
            case .scaleX: baseValue = layer.baseScaleX
            case .scaleY: baseValue = layer.baseScaleY
            case .rotation: baseValue = layer.baseRotation
            case .x: baseValue = layer.x
            case .y: baseValue = layer.y
            case .width: baseValue = layer.width
            case .height: baseValue = layer.height
            case .opacity: baseValue = layer.opacity
            case .cornerRadius: baseValue = layer.cornerRadius
            case .borderWidth: baseValue = layer.borderWidth
            case .color, .isOn: baseValue = graphValueFromBase(property: property, layer: layer)
            default: baseValue = nil
            }
            values = keyValues + (baseValue.map { [$0] } ?? [])
        } else {
            values = [0]
        }

        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? minValue
        let span = max(maxValue - minValue, property == .scaleX || property == .scaleY ? 0.2 : property == .rotation ? 20 : 1)
        valueCenter = (minValue + maxValue) * 0.5
        if property == .scaleX || property == .scaleY { valueCenter = 1 }
        if property == .rotation { valueCenter = (minValue + maxValue) * 0.5 }

        let drawableHeight = max(60, bounds.height - topAxisHeight - 18)
        valueScale = max(0.5, drawableHeight / (span * 1.35))
    }

    private func graphValueFromBase(property: MainViewController.AnimatedProperty, layer: MainViewController.LayerModel) -> CGFloat {
        switch property {
        case .opacity: return layer.opacity
        case .cornerRadius: return layer.cornerRadius
        case .borderWidth: return layer.borderWidth
        case .color: return MainViewController.ColorValue.from(layer.color).brightness
        case .isOn: return layer.isOn ? 1 : 0
        default: return 0
        }
    }

    private func frameToX(_ frame: Int) -> CGFloat { leftAxisWidth + (CGFloat(frame) - timeOrigin) * timeScale }
    private func xToFrame(_ x: CGFloat) -> Int { max(0, Int((timeOrigin + (x-leftAxisWidth)/max(0.1,timeScale)).rounded())) }
    private func valueToY(_ value: CGFloat) -> CGFloat { bounds.midY - (value - valueCenter) * valueScale }
    private func yToValue(_ y: CGFloat) -> CGFloat { valueCenter + (bounds.midY-y)/max(0.01,valueScale) }
    private func formatGraphValue(_ value: CGFloat) -> String { abs(value.rounded()-value) < 0.01 ? String(Int(value.rounded())) : String(format: "%.1f", Double(value)) }

    private func pointFor(layer: MainViewController.LayerModel, property: MainViewController.AnimatedProperty, frame: Int) -> CurvePoint? {
        guard let k = layer.propertyKeyframes.first(where: { $0.property == property && $0.frame == frame }) else { return nil }
        return CurvePoint(layerID: layer.id, property: property, frame: frame, value: graphValue(for: k, property: property), color: colorFor(property))
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard p.x.isFinite, p.y.isFinite else {
            NSLog("[Baram Motion] ERROR: Invalid graph mouse position.")
            return
        }

        if p.y < topAxisHeight + 14 {
            let frame = xToFrame(p.x)
            delegate?.keyframeGraph(self, didSelect: selectedProperty ?? .x, frame: frame)
            return
        }

        if event.clickCount >= 2 {
            let frame = xToFrame(p.x)
            guard let property = nearestProperty(to: p) else {
                NSLog("[Baram Motion] WARNING: No property found for graph keyframe insertion.")
                return
            }
            selectedProperty = property
            selectedKeyframeFrame = frame
            delegate?.keyframeGraph(self, didAddKeyframeFor: property, at: frame)
            return
        }

        // Handles must win over keyframe points. Hit both CP handles of the selected segment.
        if let handleHit = hitHandle(at: p) {
            handleDrag = handleHit
            needsDisplay = true
            NSLog("[Baram Motion] Graph handle drag begin: %@ frame=%d handle=%d", handleHit.property.rawValue, handleHit.frame, handleHit.handleIndex + 1)
            return
        }

        guard let hit = hitPoint(at: p) else {
            NSLog("[Baram Motion] Graph mouseDown: no hit at %.1f, %.1f", p.x, p.y)
            return
        }

        selectedProperty = hit.property
        selectedKeyframeFrame = hit.frame
        drag = DragState(point: hit, startPoint: p, startFrame: hit.frame, startValue: hit.value)
        delegate?.keyframeGraph(self, didSelect: hit.property, frame: hit.frame)
        NSLog("[Baram Motion] Graph keyframe drag begin: %@ frame=%d", hit.property.rawValue, hit.frame)
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard p.x.isFinite, p.y.isFinite else {
            NSLog("[Baram Motion] ERROR: Invalid graph drag position.")
            return
        }

        if let handleDrag {
            guard let layer = layers.first(where: { $0.id == handleDrag.layerID }) else {
                NSLog("[Baram Motion] ERROR: Graph handle layer disappeared.")
                return
            }
            guard let idx = layer.propertyKeyframes.firstIndex(where: { $0.property == handleDrag.property && $0.frame == handleDrag.frame }) else {
                NSLog("[Baram Motion] ERROR: Graph handle keyframe disappeared.")
                return
            }

            let dx = p.x - handleDrag.startMouse.x
            let dy = p.y - handleDrag.startMouse.y
            let frameRange = max(1, handleDrag.frameRangePixels)
            let valueRange = handleDrag.valueRangePixels

            var newX = handleDrag.startHandle.x + dx / frameRange
            var newY = handleDrag.startHandle.y
            if abs(valueRange) > 0.01 {
                newY += dy / valueRange
            }

            // Standard cubic-bezier x is constrained to the segment; y intentionally allows overshoot.
            newX = max(0, min(1, newX))
            newY = max(-1, min(2, newY))

            if handleDrag.handleIndex == 0 {
                layer.propertyKeyframes[idx].easing.cp1 = CGPoint(x: newX, y: newY)
            } else {
                layer.propertyKeyframes[idx].easing.cp2 = CGPoint(x: newX, y: newY)
            }

            needsDisplay = true
            return
        }

        guard let drag else { return }
        let deltaX = p.x - drag.startPoint.x
        let deltaY = p.y - drag.startPoint.y
        let newFrame = max(0, drag.startFrame + Int(round(deltaX / max(0.1, timeScale))))
        var value: CGFloat? = nil

        switch drag.point.property {
        case .x, .y, .width, .height, .scaleX, .scaleY, .rotation, .opacity, .cornerRadius, .borderWidth, .color:
            // Graph Y axis is inverted: moving the mouse downward decreases the value.
            value = drag.startValue - deltaY / max(0.1, valueScale)
            if drag.point.property == .width || drag.point.property == .height { value = max(1, value ?? 1) }
            if drag.point.property == .cornerRadius { value = max(0, value ?? 0) }
            if drag.point.property == .color { value = max(0, min(1, value ?? 0)) }
        case .isOn:
            value = (drag.startValue - deltaY / max(0.1, valueScale)) >= 0.5 ? 1 : 0
        case .borderColor, .text, .font:
            // Color/text/font values are not represented as a scalar drag value.
            // The keyframe can still be moved horizontally by frame.
            value = nil
        }

        delegate?.keyframeGraph(self, didMove: drag.point.layerID, property: drag.point.property, fromFrame: drag.startFrame, toFrame: newFrame, value: value)
        self.drag = DragState(
            point: drag.point,
            startPoint: p,
            startFrame: newFrame,
            startValue: value ?? drag.startValue
        )
    }

    override func mouseUp(with event: NSEvent) {
        if let handleDrag {
            guard let layer = layers.first(where: { $0.id == handleDrag.layerID }),
                  let key = layer.propertyKeyframes.first(where: { $0.property == handleDrag.property && $0.frame == handleDrag.frame }) else {
                NSLog("[Baram Motion] ERROR: Graph handle keyframe unavailable at mouseUp.")
                self.handleDrag = nil
                self.drag = nil
                return
            }
            delegate?.keyframeGraph(
                self,
                didChangeEasingAt: handleDrag.layerID,
                property: handleDrag.property,
                frame: handleDrag.frame,
                easing: key.easing
            )
            NSLog("[Baram Motion] Graph easing committed: %@ frame=%d handle=%d", handleDrag.property.rawValue, handleDrag.frame, handleDrag.handleIndex + 1)
        } else if drag != nil {
            NSLog("[Baram Motion] Graph keyframe drag end.")
        }
        drag = nil
        handleDrag = nil
        needsDisplay = true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        let mouse = convert(window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
        addCursorRect(bounds, cursor: hitHandle(at: mouse) != nil ? .crosshair : .arrow)
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.arrow.set()
        let p = convert(event.locationInWindow, from: nil)
        if hitHandle(at: p) != nil { NSCursor.crosshair.set() }
        window?.invalidateCursorRects(for: self)
    }


    override func rightMouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard let hit = hitPoint(at: p) else { return }
        selectedProperty = hit.property; selectedKeyframeFrame = hit.frame
        let menu = NSMenu()
        for (name, bezier) in MainViewController.CubicBezier.presets {
            let item = NSMenuItem(title: name, action: #selector(selectGraphEasing(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = [hit.layerID.uuidString, hit.property.rawValue, String(hit.frame), "\(bezier.cp1.x),\(bezier.cp1.y),\(bezier.cp2.x),\(bezier.cp2.y)"]
            menu.addItem(item)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func selectGraphEasing(_ sender: NSMenuItem) {
        guard let values = sender.representedObject as? [String], values.count == 4,
              let id = UUID(uuidString: values[0]), let property = MainViewController.AnimatedProperty(rawValue: values[1]),
              let frame = Int(values[2]) else { return }
        let parts = values[3].split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4 else { return }
        let bezier = MainViewController.CubicBezier(cp1: CGPoint(x: parts[0], y: parts[1]), cp2: CGPoint(x: parts[2], y: parts[3]))
        delegate?.keyframeGraph(self, didChangeEasingAt: id, property: property, frame: frame, easing: bezier)
    }

    override func keyDown(with event: NSEvent) {
        if event.characters == "\u{8}" || event.characters == "\u{7f}" {
            if let property = selectedProperty, let frame = selectedKeyframeFrame, let id = selectedLayerID {
                delegate?.keyframeGraph(self, didDeleteKeyframeAt: id, property: property, frame: frame)
            }
            return
        }
        super.keyDown(with: event)
    }

    private func hitPoint(at p: CGPoint) -> CurvePoint? {
        guard let id = selectedLayerID, let layer = layers.first(where: { $0.id == id }) else { return nil }
        var best: (CurvePoint, CGFloat)?
        for property in MainViewController.AnimatedProperty.allCases {
            for key in layer.propertyKeyframes where key.property == property {
                let point = CurvePoint(layerID: id, property: property, frame: key.frame, value: graphValue(for: key, property: property), color: colorFor(property))
                let c = CGPoint(x: frameToX(key.frame), y: valueToY(point.value))
                let distance = hypot(c.x-p.x, c.y-p.y)
                if distance <= 10 && (best == nil || distance < best!.1) { best = (point, distance) }
            }
        }
        return best?.0
    }

    private func hitHandle(at p: CGPoint) -> HandleDragState? {
        guard let id = selectedLayerID,
              let layer = layers.first(where: { $0.id == id }) else {
            return nil
        }

        var best: (HandleDragState, CGFloat)?
        for property in MainViewController.AnimatedProperty.allCases where property.isNumeric {
            let keys = layer.propertyKeyframes.filter { $0.property == property }.sorted { $0.frame < $1.frame }
            guard keys.count >= 2 else { continue }
            for index in 0..<(keys.count - 1) {
                let key = keys[index]
                let nextKey = keys[index + 1]
                let point = CGPoint(x: frameToX(key.frame), y: valueToY(graphValue(for: key, property: property)))
                let nextPoint = CGPoint(x: frameToX(nextKey.frame), y: valueToY(graphValue(for: nextKey, property: property)))
                let frameRangePixels = max(1, CGFloat(nextKey.frame - key.frame) * timeScale)
                let valueRangePixels = nextPoint.y - point.y
                let handlePoints = [
                    graphHandlePoint(key: key, nextKey: nextKey, point: point, nextPoint: nextPoint, isStart: true),
                    graphHandlePoint(key: key, nextKey: nextKey, point: point, nextPoint: nextPoint, isStart: false)
                ]
                for (handleIndex, handlePoint) in handlePoints.enumerated() {
                    let distance = hypot(handlePoint.x - p.x, handlePoint.y - p.y)
                    guard distance <= 18 else { continue }
                    let candidate = HandleDragState(
                        layerID: id, property: property, frame: key.frame, handleIndex: handleIndex,
                        startHandle: handleIndex == 0 ? key.easing.cp1 : key.easing.cp2,
                        startMouse: p, frameRangePixels: frameRangePixels, valueRangePixels: valueRangePixels
                    )
                    if best == nil || distance < best!.1 { best = (candidate, distance) }
                }
            }
        }
        return best?.0
    }

    private func nearestProperty(to p: CGPoint) -> MainViewController.AnimatedProperty? {
        if let hit = hitPoint(at: p) { return hit.property }
        guard let layerID = selectedLayerID, let layer = layers.first(where: { $0.id == layerID }) else { return selectedProperty }
        let candidates = MainViewController.AnimatedProperty.allCases.filter { property in
            layer.propertyKeyframes.contains(where: { $0.property == property })
        }
        guard !candidates.isEmpty else { return selectedProperty }
        let frame = xToFrame(p.x)
        var best: (MainViewController.AnimatedProperty, Int)?
        for property in candidates {
            for key in layer.propertyKeyframes where key.property == property {
                if best == nil || abs(key.frame - frame) < abs(best!.1 - frame) { best = (property, key.frame) }
            }
        }
        return best?.0 ?? selectedProperty
    }

    override func magnify(with event: NSEvent) {
        timeScale = max(0.6, min(60, timeScale * (1 + event.magnification)))
        valueScale = max(0.15, min(10, valueScale * (1 + event.magnification)))
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.option) {
            let factor = 1 + (-event.scrollingDeltaY * 0.01)
            timeScale = max(0.6, min(60, timeScale * factor))
            valueScale = max(0.15, min(10, valueScale * (1 + (-event.scrollingDeltaY * 0.005))))
        } else {
            timeOrigin = max(0, timeOrigin + (-event.scrollingDeltaX / max(0.6,timeScale)))
            valueCenter += event.scrollingDeltaY / max(0.15,valueScale)
        }
        needsDisplay = true
    }
}