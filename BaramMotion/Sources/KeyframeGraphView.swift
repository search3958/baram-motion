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

    private let leftAxisWidth: CGFloat = 72
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
        let startPoint: CGPoint
        let startHandle: CGPoint
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill(); dirtyRect.fill()
        guard let id = selectedLayerID, let layer = layers.first(where: { $0.id == id }) else {
            drawAxes();
            NSString(string: "レイヤーを選択してください").draw(at: NSPoint(x: 16, y: 42), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor])
            return
        }
        drawAxes()
        for property in MainViewController.AnimatedProperty.allCases {
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

        let valueStep: CGFloat = 50
        var v = -500.0
        while valueToY(v) < bounds.height + 80 {
            let y = valueToY(v)
            if y >= topAxisHeight {
                NSColor.separatorColor.withAlphaComponent(0.18).setStroke()
                let path = NSBezierPath(); path.move(to: NSPoint(x: leftAxisWidth, y: y)); path.line(to: NSPoint(x: bounds.width, y: y)); path.lineWidth = 0.5; path.stroke()
                NSString(string: formatGraphValue(v)).draw(at: NSPoint(x: 8, y: y - 7), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular), .foregroundColor: NSColor.tertiaryLabelColor])
            }
            v += valueStep
            if v > 5000 { break }
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
            drawHandlePoints(layer: layer, property: property, key: key, index: index, keys: keys, color: color)
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
            let cp1 = handlePoint(for: keys[i], nextKey: keys[i + 1], point: p0, nextPoint: p3, isStart: true)
            let cp2 = handlePoint(for: keys[i], nextKey: keys[i + 1], point: p0, nextPoint: p3, isStart: false)
            path.curve(to: p3, controlPoint1: cp1, controlPoint2: cp2)
        }
        color.withAlphaComponent(0.72).setStroke()
        path.lineWidth = 1.4
        path.stroke()
    }

    private func handlePoint(for key: MainViewController.PropertyKeyframe, nextKey: MainViewController.PropertyKeyframe, point: CGPoint, nextPoint: CGPoint, isStart: Bool) -> CGPoint {
        let easing = key.easing
        let frameRange = CGFloat(max(1, nextKey.frame - key.frame))
        let valueRange = nextPoint.y - point.y
        let cp = isStart ? easing.cp1 : easing.cp2
        return CGPoint(x: point.x + cp.x * frameRange, y: point.y + cp.y * valueRange)
    }

    private func drawHandlePoints(layer: MainViewController.LayerModel, property: MainViewController.AnimatedProperty, key: MainViewController.PropertyKeyframe, index: Int, keys: [MainViewController.PropertyKeyframe], color: NSColor) {
        guard index < keys.count - 1 else { return }
        let nextKey = keys[index + 1]
        let point = CGPoint(x: frameToX(key.frame), y: valueToY(graphValue(for: key, property: property)))
        let nextPoint = CGPoint(x: frameToX(nextKey.frame), y: valueToY(graphValue(for: nextKey, property: property)))
        let frameRange = CGFloat(max(1, nextKey.frame - key.frame))
        let valueRange = nextPoint.y - point.y

        for (handleIndex, cp) in [key.easing.cp1, key.easing.cp2].enumerated() {
            let hx = point.x + cp.x * frameRange
            let hy = point.y + cp.y * valueRange
            let isSelected = selectedProperty == property && selectedKeyframeFrame == key.frame
            drawHandle(at: CGPoint(x: hx, y: hy), index: handleIndex, selected: isSelected, color: color)
        }
    }

    private func drawHandle(at point: CGPoint, index: Int, selected: Bool, color: NSColor) {
        let r: CGFloat = selected ? 7 : 5
        let p = NSBezierPath(ovalIn: NSRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
        if selected {
            NSColor.white.setFill()
            p.fill()
            color.setStroke()
            p.lineWidth = 2
            p.stroke()
        } else {
            color.withAlphaComponent(0.6).setFill()
            p.fill()
            color.setStroke()
            p.lineWidth = 1
            p.stroke()
        }
        let label = index == 0 ? "cp1" : "cp2"
        NSString(string: label).draw(at: NSPoint(x: point.x + r + 2, y: point.y - 7), withAttributes: [.font: NSFont.systemFont(ofSize: 7), .foregroundColor: color])
    }

    private func drawPlayhead() {
        let x = frameToX(currentFrame)
        NSColor.controlAccentColor.setStroke(); let path = NSBezierPath(); path.move(to: NSPoint(x: x, y: 0)); path.line(to: NSPoint(x: x, y: bounds.height)); path.lineWidth = 1.5; path.stroke()
        let knob = NSBezierPath(); knob.move(to: NSPoint(x: x - 6, y: 0)); knob.line(to: NSPoint(x: x + 6, y: 0)); knob.line(to: NSPoint(x: x, y: 10)); knob.close(); NSColor.controlAccentColor.setFill(); knob.fill()
    }

    private func drawSelection() {
        guard let property = selectedProperty, let frame = selectedKeyframeFrame else { return }
        let text = "\(property.rawValue) • frame \(frame)  |  ←→ 時間  ↑↓ 値  |  ⌥スクロール/ピンチで拡大縮小  |  ダブルクリックで追加  |  BackSpaceで削除"
        NSString(string: text).draw(at: NSPoint(x: 8, y: bounds.height - 20), withAttributes: [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.tertiaryLabelColor])
    }

    private func colorFor(_ property: MainViewController.AnimatedProperty) -> NSColor {
        switch property {
        case .x: return .systemRed
        case .y: return .systemGreen
        case .width: return .systemBlue
        case .height: return .systemOrange
        case .cornerRadius: return .systemPurple
        case .color: return .systemTeal
        case .text: return .systemPink
        case .isOn: return .systemYellow
        }
    }

    private func graphValue(for key: MainViewController.PropertyKeyframe, property: MainViewController.AnimatedProperty) -> CGFloat {
        switch property {
        case .x,.y,.width,.height,.cornerRadius: return key.scalar
        case .isOn: return key.boolValue ? 1 : 0
        case .text: return 0
        case .color: return key.scalar
        }
    }

    private func frameToX(_ frame: Int) -> CGFloat { leftAxisWidth + (CGFloat(frame) - timeOrigin) * timeScale }
    private func xToFrame(_ x: CGFloat) -> Int { max(0, Int((timeOrigin + (x-leftAxisWidth)/max(0.1,timeScale)).rounded())) }
    private func valueToY(_ value: CGFloat) -> CGFloat { bounds.midY - (value - valueCenter) * valueScale }
    private func yToValue(_ y: CGFloat) -> CGFloat { valueCenter + (bounds.midY-y)/max(0.01,valueScale) }
    private func formatGraphValue(_ value: CGFloat) -> String { abs(value.rounded()-value) < 0.01 ? String(Int(value.rounded())) : String(format: "%.1f", Double(value)) }

    private func drawDiamond(at point: CGPoint, filled: Bool, color: NSColor, selected: Bool) {
        let r: CGFloat = selected ? 6 : 5
        let p = NSBezierPath(); p.move(to: NSPoint(x: point.x, y: point.y-r)); p.line(to: NSPoint(x: point.x+r, y: point.y)); p.line(to: NSPoint(x: point.x, y: point.y+r)); p.line(to: NSPoint(x: point.x-r, y: point.y)); p.close()
        color.setFill(); p.fill(); if selected { NSColor.white.setStroke(); p.lineWidth = 1; p.stroke() }
    }

    private func pointFor(layer: MainViewController.LayerModel, property: MainViewController.AnimatedProperty, frame: Int) -> CurvePoint? {
        guard let k = layer.propertyKeyframes.first(where: { $0.property == property && $0.frame == frame }) else { return nil }
        return CurvePoint(layerID: layer.id, property: property, frame: frame, value: graphValue(for: k, property: property), color: colorFor(property))
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if p.y < topAxisHeight + 14 {
            let frame = xToFrame(p.x); delegate?.keyframeGraph(self, didSelect: selectedProperty ?? .x, frame: frame); return
        }
        if event.clickCount >= 2 {
            let frame = xToFrame(p.x)
            guard let property = nearestProperty(to: p) else { return }
            selectedProperty = property
            selectedKeyframeFrame = frame
            delegate?.keyframeGraph(self, didAddKeyframeFor: property, at: frame)
            return
        }
        if let handleHit = hitHandle(at: p) {
            handleDrag = handleHit
            return
        }
        guard let hit = hitPoint(at: p) else { return }
        selectedProperty = hit.property; selectedKeyframeFrame = hit.frame
        drag = DragState(point: hit, startPoint: p, startFrame: hit.frame, startValue: hit.value)
        delegate?.keyframeGraph(self, didSelect: hit.property, frame: hit.frame)
    }

    override func mouseDragged(with event: NSEvent) {
        if let handleDrag {
            let p = convert(event.locationInWindow, from: nil)
            guard let layer = layers.first(where: { $0.id == handleDrag.layerID }) else { return }
            guard let idx = layer.propertyKeyframes.firstIndex(where: { $0.property == handleDrag.property && $0.frame == handleDrag.frame }) else { return }
            let frameRange = CGFloat(max(1, layer.propertyKeyframes.first(where: { $0.property == handleDrag.property && $0.frame > handleDrag.frame })?.frame ?? handleDrag.frame + 10 - handleDrag.frame))
            let valueRange: CGFloat = 1
            let dx = p.x - handleDrag.startPoint.x
            let dy = p.y - handleDrag.startPoint.y
            let newCp1x = max(0, min(1, handleDrag.startHandle.x / frameRange + dx / frameRange))
            let newCp1y = max(0, min(1, handleDrag.startHandle.y / valueRange + dy / valueRange))
            if handleDrag.handleIndex == 0 {
                layer.propertyKeyframes[idx].easing.cp1.x = newCp1x
                layer.propertyKeyframes[idx].easing.cp1.y = newCp1y
            } else {
                layer.propertyKeyframes[idx].easing.cp2.x = newCp1x
                layer.propertyKeyframes[idx].easing.cp2.y = newCp1y
            }
            needsDisplay = true
            return
        }
        guard let drag else { return }
        let p = convert(event.locationInWindow, from: nil)
        let newFrame = xToFrame(p.x)
        var value: CGFloat? = nil
        switch drag.point.property {
        case .x,.y,.width,.height,.cornerRadius,.color:
            value = yToValue(p.y)
            if drag.point.property == .width || drag.point.property == .height { value = max(1, value ?? 1) }
            if drag.point.property == .cornerRadius { value = max(0, value ?? 0) }
            if drag.point.property == .color { value = max(0, min(1, value ?? 0)) }
        case .isOn: value = yToValue(p.y) >= 0.5 ? 1 : 0
        case .text: value = nil
        }
        delegate?.keyframeGraph(self, didMove: drag.point.layerID, property: drag.point.property, fromFrame: drag.startFrame, toFrame: newFrame, value: value)
    }

    override func mouseUp(with event: NSEvent) {
        drag = nil
        handleDrag = nil
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
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
        guard let id = selectedLayerID, let layer = layers.first(where: { $0.id == id }) else { return nil }
        guard let property = selectedProperty, let frame = selectedKeyframeFrame else { return nil }
        guard let idx = layer.propertyKeyframes.firstIndex(where: { $0.property == property && $0.frame == frame }) else { return nil }
        guard idx < layer.propertyKeyframes.count - 1 else { return nil }
        let key = layer.propertyKeyframes[idx]
        let nextKey = layer.propertyKeyframes[idx + 1]
        let point = CGPoint(x: frameToX(key.frame), y: valueToY(graphValue(for: key, property: property)))
        let nextPoint = CGPoint(x: frameToX(nextKey.frame), y: valueToY(graphValue(for: nextKey, property: property)))
        let frameRange = CGFloat(max(1, nextKey.frame - key.frame))
        let valueRange = nextPoint.y - point.y

        for (handleIndex, cp) in [key.easing.cp1, key.easing.cp2].enumerated() {
            let hx = point.x + cp.x * frameRange
            let hy = point.y + cp.y * valueRange
            let distance = hypot(hx - p.x, hy - p.y)
            if distance <= 12 {
                return HandleDragState(layerID: id, property: property, frame: frame, handleIndex: handleIndex, startPoint: p, startHandle: cp)
            }
        }
        return nil
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