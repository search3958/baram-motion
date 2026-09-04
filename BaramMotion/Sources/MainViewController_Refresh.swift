import AppKit
import SwiftUI
import Combine

extension MainViewController {

    // MARK: - Refresh

    func refreshAll() {

        refreshPreview()
        refreshLayerList()
        refreshInspectorValues()
        refreshKeyframeInspector()
        refreshSelectionAppearance()
        updateTimelineSize()

        timelineContent.reload(layers: timelineProxies, selectedLayerID: selectedLayerID)
        timelineLayerPanel?.reload(layers: timelineProxies, selectedLayerID: selectedLayerID)
        syncTimelineLayerPanelScroll()

        refreshPlaybackUI()
    }

    var timelineProxies: [LayerModelProxy] { timelineProxiesForUI() }

    func timelineProxiesForUI() -> [LayerModelProxy] {
        layers.map {
            LayerModelProxy(id:$0.id, kindDisplayName:$0.kind.displayName, name:$0.name,
                            color:$0.color, startTime:$0.startTime, duration:$0.duration,
                            isVisible:$0.isVisible, keyframeFrames:Array(Set($0.propertyKeyframes.map(\.frame))).sorted())
        }
    }

    func evaluatedNumeric(for layer: LayerModel, property: AnimatedProperty, frame: Int, defaultValue: CGFloat) -> CGFloat {
        let keys = layer.propertyKeyframes.filter { $0.property == property }.sorted { $0.frame < $1.frame }
        guard !keys.isEmpty else { return defaultValue }
        if frame <= keys[0].frame { return keys[0].scalar }
        guard let next = keys.firstIndex(where: { $0.frame >= frame }) else { return keys.last?.scalar ?? defaultValue }
        if keys[next].frame == frame { return keys[next].scalar }
        let a = keys[next - 1], b = keys[next]
        let range = CGFloat(max(1, b.frame - a.frame))
        let raw = CGFloat(frame - a.frame) / range
        return lerp(a.scalar, b.scalar, easedProgress(raw, easing: a.easing))
    }

    func evaluatedTransform(for layer: LayerModel, frame: Int) -> TransformValue {
        TransformValue(
            x: evaluatedNumeric(for: layer, property: .x, frame: frame, defaultValue: layer.x),
            y: evaluatedNumeric(for: layer, property: .y, frame: frame, defaultValue: layer.y),
            width: max(1, evaluatedNumeric(for: layer, property: .width, frame: frame, defaultValue: layer.width)),
            height: max(1, evaluatedNumeric(for: layer, property: .height, frame: frame, defaultValue: layer.height))
        )
    }

    func evaluatedCornerRadius(for layer: LayerModel, frame: Int) -> CGFloat {
        max(0, evaluatedNumeric(for: layer, property: .cornerRadius, frame: frame, defaultValue: layer.cornerRadius))
    }

    func evaluatedText(for layer: LayerModel, frame: Int) -> String {
        let keys = layer.propertyKeyframes
            .filter { $0.property == .text }
            .sorted { $0.frame < $1.frame }
        guard !keys.isEmpty else { return layer.text }
        if frame <= keys[0].frame { return keys[0].text }
        guard let nextIndex = keys.firstIndex(where: { $0.frame >= frame }) else {
            return keys.last?.text ?? layer.text
        }
        if keys[nextIndex].frame == frame { return keys[nextIndex].text }
        return keys[nextIndex - 1].text
    }

    func evaluatedSwitchState(for layer: LayerModel, frame: Int) -> Bool {
        let keys = layer.propertyKeyframes
            .filter { $0.property == .isOn }
            .sorted { $0.frame < $1.frame }
        guard !keys.isEmpty else { return layer.isOn }
        if frame <= keys[0].frame { return keys[0].boolValue }
        guard let nextIndex = keys.firstIndex(where: { $0.frame >= frame }) else {
            return keys.last?.boolValue ?? layer.isOn
        }
        if keys[nextIndex].frame == frame { return keys[nextIndex].boolValue }
        return keys[nextIndex - 1].boolValue
    }

    func evaluatedColor(for layer: LayerModel, frame: Int) -> NSColor {
        let keys = layer.propertyKeyframes.filter { $0.property == .color }.sorted { $0.frame < $1.frame }
        guard !keys.isEmpty else { return layer.color }
        guard let first = keys.first else { return layer.color }
        if frame <= first.frame { return (first.colorValue ?? ColorValue.from(layer.color)).nsColor() }
        guard let nextIndex = keys.firstIndex(where: { $0.frame >= frame }) else {
            return (keys.last?.colorValue ?? ColorValue.from(layer.color)).nsColor()
        }
        if keys[nextIndex].frame == frame { return (keys[nextIndex].colorValue ?? ColorValue.from(layer.color)).nsColor() }
        let a = keys[nextIndex - 1].colorValue ?? ColorValue.from(layer.color)
        let b = keys[nextIndex].colorValue ?? a
        let raw = CGFloat(frame - keys[nextIndex - 1].frame) / CGFloat(max(1, keys[nextIndex].frame - keys[nextIndex - 1].frame))
        let t = easedProgress(raw, easing: keys[nextIndex - 1].easing)
        return ColorValue(r: a.r+(b.r-a.r)*t, g:a.g+(b.g-a.g)*t, b:a.b+(b.b-a.b)*t, a:a.a+(b.a-a.a)*t).nsColor()
    }

    func easedProgress(_ value: CGFloat, easing: KeyframeEasing) -> CGFloat {
        let t=max(0,min(1,value))
        switch easing {
        case .linear: return t
        case .easeIn: return t*t
        case .easeOut: return 1-(1-t)*(1-t)
        case .easeInOut:
            return t < 0.5 ? 2*t*t : 1-pow(-2*t+2,2)/2
        }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a+(b-a)*t }

    func refreshPreview() {
        guard let previewView else { NSLog("[Baram Motion] ERROR: Preview view is nil."); return }
        previewElementViews.values.forEach { $0.removeFromSuperview() }
        previewElementViews.removeAll(keepingCapacity:true)
        let frame=playbackController.currentFrame
        let time=CGFloat(frame)/playbackFrameRate

        // First item in the layer panel is visually on top. Add lower layers first.
        for layer in layers.reversed() {
            guard layer.isVisible, layer.startTime <= time, time < layer.startTime+layer.duration else { continue }
            let element=PreviewElementView(layerID:layer.id, kind:layer.kind)
            let evaluatedColor = evaluatedColor(for: layer, frame: frame)
            element.backgroundColor=evaluatedColor
            element.switchTint=Color(nsColor:evaluatedColor)
            element.fontSize=layer.fontSize
            element.text=evaluatedText(for:layer,frame:frame)
            element.isOn=evaluatedSwitchState(for:layer,frame:frame)
            let transform=evaluatedTransform(for:layer,frame:frame)
            let displayLayer=layer.copyLayer()
            displayLayer.x=transform.x; displayLayer.y=transform.y
            displayLayer.width=transform.width; displayLayer.height=transform.height
            displayLayer.cornerRadius = evaluatedCornerRadius(for: layer, frame: frame)
            element.cornerRadius = displayLayer.cornerRadius
            element.frame=frameForLayer(displayLayer)
            element.onSelect={ [weak self] id in self?.selectLayer(id) }
            element.onBeginMove={ [weak self] id in self?.beginPreviewLayerEditing(id) }
            element.onMove={ [weak self] id,delta in self?.movePreviewLayer(id,deltaX:delta.x,deltaY:delta.y) }
            element.onEndMove={ [weak self] id in self?.finishPreviewLayerEditing(id) }
            element.onToggleChanged={ [weak self] id,value in self?.setSwitchState(for:id,isOn:value) }
            previewView.addSubview(element)
            previewElementViews[layer.id]=element
            element.updateAppearance(selected:layer.id==selectedLayerID)
        }
    }

    func refreshSelectionAppearance() {

        for layer in layers {

            guard let element =
                    previewElementViews[layer.id] else {

                continue
            }

            element.updateAppearance(
                selected:
                    layer.id
                    == selectedLayerID
            )
        }
    }

    // MARK: - Inspector Refresh

    func refreshInspectorValues() {

        guard let layer =
                selectedLayer else {

            rebuildInspector()

            return
        }

        colorWell?.color =
            evaluatedColor(for: layer, frame: playbackController.currentFrame)

        anchorPopup?.selectItem(
            at:
                layer.anchor.rawValue
        )

        let transform = evaluatedTransform(for: layer, frame: playbackController.currentFrame)
        xField?.stringValue = formatNumber(transform.x)
        yField?.stringValue = formatNumber(transform.y)
        widthField?.stringValue = formatNumber(transform.width)
        heightField?.stringValue = formatNumber(transform.height)

        cornerRadiusField?.stringValue = formatNumber(evaluatedCornerRadius(for: layer, frame: playbackController.currentFrame))

        fontSizeField?.stringValue =
            formatNumber(
                layer.fontSize
            )

        let switchTransform = evaluatedTransform(for: layer, frame: playbackController.currentFrame)
        switchWidthField?.stringValue = formatNumber(switchTransform.width)
        switchHeightField?.stringValue = formatNumber(switchTransform.height)

        for (property, button) in keyframeButtons {
            button.title = keyframeFor(property: property, layer: layer, frame: playbackController.currentFrame) ? "◆" : "◇"
        }

        if let textContentField, layer.kind == .text {
            textContentField.stringValue = evaluatedText(for: layer, frame: playbackController.currentFrame)
        }

    }

    // MARK: - Geometry

    func frameForLayer(
        _ layer: LayerModel
    ) -> NSRect {

        switch layer.anchor {

        case .topLeft:

            return NSRect(
                x:
                    layer.x,
                y:
                    Layout.previewHeight
                    - layer.y
                    - layer.height,
                width:
                    layer.width,
                height:
                    layer.height
            )

        case .center:

            return NSRect(
                x:
                    layer.x
                    - layer.width / 2,
                y:
                    Layout.previewHeight
                    - layer.y
                    - layer.height / 2,
                width:
                    layer.width,
                height:
                    layer.height
            )
        }
    }

    func positionForFrame(
        _ frame: NSRect,
        anchor:
            PositionAnchor
    ) -> CGPoint {

        switch anchor {

        case .topLeft:

            return CGPoint(
                x:
                    frame.minX,
                y:
                    Layout.previewHeight
                    - frame.maxY
            )

        case .center:

            return CGPoint(
                x:
                    frame.midX,
                y:
                    Layout.previewHeight
                    - frame.midY
            )
        }
    }

    func clampLayerPosition(
        _ layer: LayerModel
    ) {

        switch layer.anchor {

        case .topLeft:

            layer.x =
                max(
                    0,
                    min(
                        Layout.previewWidth
                        - layer.width,
                        layer.x
                    )
                )

            layer.y =
                max(
                    0,
                    min(
                        Layout.previewHeight
                        - layer.height,
                        layer.y
                    )
                )

        case .center:

            layer.x =
                max(
                    layer.width / 2,
                    min(
                        Layout.previewWidth
                        - layer.width / 2,
                        layer.x
                    )
                )

            layer.y =
                max(
                    layer.height / 2,
                    min(
                        Layout.previewHeight
                        - layer.height / 2,
                        layer.y
                    )
                )
        }
    }

    // MARK: - Timeline Size

    func updateTimelineSize() {

        guard timelineContent != nil else {
            return
        }

        let maximumEnd =
            layers.reduce(
                CGFloat(0)
            ) {
                max(
                    $0,
                    $1.startTime
                    + $1.duration
                )
            }

        let requiredWidth =
            (maximumEnd + 5)
            * Layout.timelineScale

        let width =
            max(
                Layout.minimumTimelineWidth,
                requiredWidth
            )

        let rowHeight:
            CGFloat = 34

        let rulerHeight:
            CGFloat = 28

        let totalHeight =
            rulerHeight
            + max(
                1,
                CGFloat(layers.count)
            )
            * rowHeight
            + 16

        timelineContent.frame =
            NSRect(
                x: 0,
                y: 0,
                width: width,
                height: totalHeight
            )
    }

    // MARK: - Utils

    func formatNumber(
        _ value: CGFloat
    ) -> String {

        if abs(
            value.rounded() - value
        ) < 0.001 {

            return String(
                Int(value.rounded())
            )
        }

        return String(
            format: "%.2f",
            Double(value)
        )
    }
}
