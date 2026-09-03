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

    // MARK: - Preview Rendering

    func timelineProxiesForUI() -> [LayerModelProxy] {
        layers.map {
            LayerModelProxy(id:$0.id, kindDisplayName:$0.kind.displayName, name:$0.name,
                            color:$0.color, startTime:$0.startTime, duration:$0.duration,
                            isVisible:$0.isVisible, keyframeFrames:$0.keyframes.map(\.frame))
        }
    }

    func evaluatedTransform(for layer: LayerModel, frame: Int) -> TransformValue {
        let keyframes=layer.keyframes.sorted { $0.frame < $1.frame }
        guard !keyframes.isEmpty else { return layer.currentTransform() }
        if frame <= keyframes[0].frame { return keyframes[0].value }
        guard let nextIndex=keyframes.firstIndex(where:{ $0.frame >= frame }) else { return keyframes.last!.value }
        if keyframes[nextIndex].frame == frame { return keyframes[nextIndex].value }
        let a=keyframes[nextIndex-1], b=keyframes[nextIndex]
        let range=CGFloat(b.frame-a.frame)
        let raw=range > 0 ? CGFloat(frame-a.frame)/range : 0
        let t=easedProgress(raw, easing:a.easing)
        return TransformValue(
            x: lerp(a.x,b.x,t), y: lerp(a.y,b.y,t),
            width: lerp(a.width,b.width,t), height: lerp(a.height,b.height,t)
        )
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
            element.backgroundColor=layer.color
            element.switchTint=Color(nsColor:layer.color)
            element.fontSize=layer.fontSize
            element.text=layer.name
            element.isOn=layer.isOn
            let transform=evaluatedTransform(for:layer,frame:frame)
            let displayLayer=layer.copyLayer()
            displayLayer.x=transform.x; displayLayer.y=transform.y
            displayLayer.width=transform.width; displayLayer.height=transform.height
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
            layer.color

        anchorPopup?.selectItem(
            at:
                layer.anchor.rawValue
        )

        let transform = evaluatedTransform(for: layer, frame: playbackController.currentFrame)
        xField?.stringValue = formatNumber(transform.x)
        yField?.stringValue = formatNumber(transform.y)
        widthField?.stringValue = formatNumber(transform.width)
        heightField?.stringValue = formatNumber(transform.height)

        fontSizeField?.stringValue =
            formatNumber(
                layer.fontSize
            )

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
