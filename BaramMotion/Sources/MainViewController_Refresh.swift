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
        return lerp(a.scalar, b.scalar, a.easing.solve(raw))
    }

    func evaluatedTransform(for layer: LayerModel, frame: Int) -> TransformValue {
        // Scale X/Y and rotation are persistent base transforms. They are applied
        // to every frame, while position and size may be animated independently.
        // This prevents frame-by-frame transform keyframes from resetting or
        // replacing the layer's permanent transform.
        TransformValue(
            x: evaluatedNumeric(for: layer, property: .x, frame: frame, defaultValue: layer.x),
            y: evaluatedNumeric(for: layer, property: .y, frame: frame, defaultValue: layer.y),
            width: max(1, evaluatedNumeric(for: layer, property: .width, frame: frame, defaultValue: layer.width)),
            height: max(1, evaluatedNumeric(for: layer, property: .height, frame: frame, defaultValue: layer.height)),
            scaleX: max(0.001, layer.baseScaleX),
            scaleY: max(0.001, layer.baseScaleY),
            rotation: layer.baseRotation
        )
    }

    func evaluatedCornerRadius(for layer: LayerModel, frame: Int) -> CGFloat {
        max(0, evaluatedNumeric(for: layer, property: .cornerRadius, frame: frame, defaultValue: layer.cornerRadius))
    }

    func evaluatedOpacity(for layer: LayerModel, frame: Int) -> CGFloat {
        max(0, min(1, evaluatedNumeric(for: layer, property: .opacity, frame: frame, defaultValue: layer.opacity)))
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


    func evaluatedFontName(for layer: LayerModel, frame: Int) -> String {
        let keys = layer.propertyKeyframes.filter { $0.property == .font }.sorted { $0.frame < $1.frame }
        guard let first = keys.first else { return layer.fontName }
        if frame <= first.frame { return first.fontName.isEmpty ? layer.fontName : first.fontName }
        guard let nextIndex = keys.firstIndex(where: { $0.frame >= frame }) else { return keys.last?.fontName.isEmpty == true ? layer.fontName : (keys.last?.fontName ?? layer.fontName) }
        if keys[nextIndex].frame == frame { return keys[nextIndex].fontName.isEmpty ? layer.fontName : keys[nextIndex].fontName }
        let value = keys[nextIndex - 1].fontName
        return value.isEmpty ? layer.fontName : value
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
        let t = keys[nextIndex - 1].easing.solve(raw)
        return ColorValue(r: a.r+(b.r-a.r)*t, g:a.g+(b.g-a.g)*t, b:a.b+(b.b-a.b)*t, a:a.a+(b.a-a.a)*t).nsColor()
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
            element.opacity=evaluatedOpacity(for: layer, frame: frame)
            element.borderWidth=evaluatedNumeric(for: layer, property: .borderWidth, frame: frame, defaultValue: layer.borderWidth)
            element.borderColor=layer.borderColor
            element.borderPosition=layer.borderPosition
            element.switchTint=Color(nsColor:evaluatedColor)
            element.fontSize=layer.fontSize
            element.fontName=evaluatedFontName(for: layer, frame: frame)
            element.text=evaluatedText(for:layer,frame:frame)
            element.textHorizontalAlignment=layer.textHorizontalAlignment
            element.textVerticalAlignment=layer.textVerticalAlignment
            element.isOn=evaluatedSwitchState(for:layer,frame:frame)
            let transform=evaluatedTransform(for:layer,frame:frame)
            let displayLayer=layer.copyLayer()
            displayLayer.x=transform.x; displayLayer.y=transform.y
            displayLayer.width=transform.width; displayLayer.height=transform.height
            displayLayer.cornerRadius = evaluatedCornerRadius(for: layer, frame: frame)
            element.cornerRadius = min(displayLayer.cornerRadius, min(displayLayer.width, displayLayer.height) * 0.5)
            element.frame=frameForLayer(displayLayer)
            element.scaleX = transform.scaleX
            element.scaleY = transform.scaleY
            element.rotation = transform.rotation
            element.onSelect={ [weak self] id in self?.selectLayer(id, shouldRefreshPreview: false) }
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

        isRefreshingInspectorValues = true
        defer { isRefreshingInspectorValues = false }

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
        scaleXField?.stringValue = formatNumber(transform.scaleX)
        scaleYField?.stringValue = formatNumber(transform.scaleY)
        rotationField?.stringValue = formatNumber(transform.rotation)
        baseScaleXField?.stringValue = formatNumber(layer.baseScaleX)
        baseScaleYField?.stringValue = formatNumber(layer.baseScaleY)
        baseRotationField?.stringValue = formatNumber(layer.baseRotation)
        opacityField?.stringValue = formatNumber(evaluatedOpacity(for: layer, frame: playbackController.currentFrame) * 100)
        borderWidthField?.stringValue = formatNumber(evaluatedNumeric(for: layer, property: .borderWidth, frame: playbackController.currentFrame, defaultValue: layer.borderWidth))

        cornerRadiusField?.stringValue = formatNumber(evaluatedCornerRadius(for: layer, frame: playbackController.currentFrame))

        fontSizeField?.stringValue = formatNumber(layer.fontSize)
        fontPopup?.selectItem(withTitle: evaluatedFontName(for: layer, frame: playbackController.currentFrame))

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

    func frameForLayer(_ layer: LayerModel) -> NSRect {
        let w = max(1, layer.width)
        let h = max(1, layer.height)
        let anchorX: CGFloat
        let anchorY: CGFloat
        switch layer.anchor {
        case .topLeft, .left, .bottomLeft: anchorX = 0
        case .top, .center, .bottom: anchorX = Layout.previewWidth * 0.5
        case .topRight, .right, .bottomRight: anchorX = Layout.previewWidth
        }
        switch layer.anchor {
        case .topLeft, .top, .topRight: anchorY = 0
        case .left, .center, .right: anchorY = Layout.previewHeight * 0.5
        case .bottomLeft, .bottom, .bottomRight: anchorY = Layout.previewHeight
        }
        let localAnchorX: CGFloat
        let localAnchorY: CGFloat
        switch layer.anchor {
        case .topLeft, .top, .topRight: localAnchorY = 0
        case .left, .center, .right: localAnchorY = h * 0.5
        case .bottomLeft, .bottom, .bottomRight: localAnchorY = h
        }
        switch layer.anchor {
        case .topLeft, .left, .bottomLeft: localAnchorX = 0
        case .top, .center, .bottom: localAnchorX = w * 0.5
        case .topRight, .right, .bottomRight: localAnchorX = w
        }
        let topLeftX = anchorX + layer.x - localAnchorX
        let topLeftY = anchorY + layer.y - localAnchorY
        return NSRect(x: topLeftX, y: Layout.previewHeight - topLeftY - h, width: w, height: h)
    }

    func positionForFrame(_ frame: NSRect, anchor: PositionAnchor) -> CGPoint {
        let topY = Layout.previewHeight - frame.maxY
        let frameAnchorX: CGFloat
        let frameAnchorY: CGFloat
        switch anchor {
        case .topLeft, .left, .bottomLeft: frameAnchorX = 0
        case .top, .center, .bottom: frameAnchorX = Layout.previewWidth * 0.5
        case .topRight, .right, .bottomRight: frameAnchorX = Layout.previewWidth
        }
        switch anchor {
        case .topLeft, .top, .topRight: frameAnchorY = 0
        case .left, .center, .right: frameAnchorY = Layout.previewHeight * 0.5
        case .bottomLeft, .bottom, .bottomRight: frameAnchorY = Layout.previewHeight
        }
        let localAnchorX: CGFloat
        let localAnchorY: CGFloat
        switch anchor {
        case .topLeft, .left, .bottomLeft: localAnchorX = 0
        case .top, .center, .bottom: localAnchorX = frame.width * 0.5
        case .topRight, .right, .bottomRight: localAnchorX = frame.width
        }
        switch anchor {
        case .topLeft, .top, .topRight: localAnchorY = 0
        case .left, .center, .right: localAnchorY = frame.height * 0.5
        case .bottomLeft, .bottom, .bottomRight: localAnchorY = frame.height
        }
        let actualAnchorX = frame.minX + localAnchorX
        let actualAnchorY = topY + localAnchorY
        return CGPoint(x: actualAnchorX - frameAnchorX, y: actualAnchorY - frameAnchorY)
    }

    func clampLayerPosition(_ layer: LayerModel) {
        let w=max(1,layer.width), h=max(1,layer.height)
        let xLimits: (CGFloat,CGFloat), yLimits:(CGFloat,CGFloat)
        switch layer.anchor {
        case .topLeft: xLimits=(0,Layout.previewWidth-w); yLimits=(0,Layout.previewHeight-h)
        case .top: xLimits=(w*0.5,Layout.previewWidth-w*0.5); yLimits=(0,Layout.previewHeight-h)
        case .topRight: xLimits=(w,Layout.previewWidth); yLimits=(0,Layout.previewHeight-h)
        case .left: xLimits=(0,Layout.previewWidth-w); yLimits=(h*0.5,Layout.previewHeight-h*0.5)
        case .center: xLimits=(w*0.5,Layout.previewWidth-w*0.5); yLimits=(h*0.5,Layout.previewHeight-h*0.5)
        case .right: xLimits=(w,Layout.previewWidth); yLimits=(h*0.5,Layout.previewHeight-h*0.5)
        case .bottomLeft: xLimits=(0,Layout.previewWidth-w); yLimits=(h,Layout.previewHeight)
        case .bottom: xLimits=(w*0.5,Layout.previewWidth-w*0.5); yLimits=(h,Layout.previewHeight)
        case .bottomRight: xLimits=(w,Layout.previewWidth); yLimits=(h,Layout.previewHeight)
        }
        layer.x=max(min(xLimits.1,max(xLimits.0,layer.x)),xLimits.0)
        layer.y=max(min(yLimits.1,max(yLimits.0,layer.y)),yLimits.0)
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
            * timelinePixelsPerSecond

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
