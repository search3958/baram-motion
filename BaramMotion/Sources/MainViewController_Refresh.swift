import AppKit
import SwiftUI
import Combine

extension MainViewController {

    // MARK: - Refresh

    func refreshAll() {

        refreshPreview()
        refreshLayerList()
        refreshInspectorValues()
        refreshSelectionAppearance()
        updateTimelineSize()

        timelineContent.reload(
            layers:
                timelineProxies,
            selectedLayerID:
                selectedLayerID
        )

        refreshPlaybackUI()
    }

    var timelineProxies:
        [LayerModelProxy] {

        return layers.map {
            LayerModelProxy(
                id: $0.id,
                kindDisplayName:
                    $0.kind.displayName,
                name: $0.name,
                color: $0.color,
                startTime: $0.startTime,
                duration: $0.duration
            )
        }
    }

    // MARK: - Preview Rendering

    func refreshPreview() {

        guard previewView != nil else {
            NSLog("[Baram Motion] ERROR: Preview view is nil.")
            return
        }

        for elementView in previewElementViews.values {
            elementView.removeFromSuperview()
        }

        previewElementViews.removeAll(keepingCapacity: true)

        let currentTime = CGFloat(playbackController.currentFrame) / playbackFrameRate

        for layer in layers {
            let isVisible = layer.startTime <= currentTime && currentTime < layer.startTime + layer.duration
            guard isVisible else { continue }

            let element = PreviewElementView(
                layerID: layer.id,
                kind: layer.kind
            )

            element.onSelect = { [weak self] id in
                guard let self else {
                    NSLog("[Baram Motion] ERROR: MainViewController released before preview selection.")
                    return
                }
                self.selectLayer(id)
            }

            element.onBeginMove = { [weak self] id in
                self?.beginPreviewLayerEditing(id)
            }

            element.onMove = { [weak self] id, delta in
                self?.movePreviewLayer(
                    id,
                    deltaX: delta.x,
                    deltaY: delta.y
                )
            }

            element.onEndMove = { [weak self] id in
                self?.finishPreviewLayerEditing(id)
            }

            element.onToggleChanged = { [weak self] id, isOn in
                self?.setSwitchState(for: id, isOn: isOn)
            }

            element.backgroundColor = layer.color
            element.fontSize = layer.fontSize
            element.text = layer.name
            element.isOn = layer.isOn
            element.frame = frameForLayer(layer)

            previewView.addSubview(element)
            previewElementViews[layer.id] = element

            element.updateAppearance(
                selected: layer.id == selectedLayerID
            )
        }

        NSLog(
            "[Baram Motion] Preview refreshed at frame %d: visible layers=%d / total=%d",
            playbackController.currentFrame,
            previewElementViews.count,
            layers.count
        )
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

        xField?.stringValue =
            formatNumber(layer.x)

        yField?.stringValue =
            formatNumber(layer.y)

        widthField?.stringValue =
            formatNumber(layer.width)

        heightField?.stringValue =
            formatNumber(layer.height)

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

// MARK: - Toolbar Delegate

extension MainViewController:
    NSToolbarDelegate {

    enum ToolbarItemID {

        static let undo =
            NSToolbarItem.Identifier(
                "BaramMotion.Undo"
            )

        static let redo =
            NSToolbarItem.Identifier(
                "BaramMotion.Redo"
            )

        static let text =
            NSToolbarItem.Identifier(
                "BaramMotion.Text"
            )

        static let rectangle =
            NSToolbarItem.Identifier(
                "BaramMotion.Rectangle"
            )

        static let toggle =
            NSToolbarItem.Identifier(
                "BaramMotion.Toggle"
            )

        static let flexible =
            NSToolbarItem.Identifier
                .flexibleSpace
    }

    func toolbarAllowedItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [
        NSToolbarItem.Identifier
    ] {

        return [
            ToolbarItemID.undo,
            ToolbarItemID.redo,
            ToolbarItemID.flexible,
            ToolbarItemID.text,
            ToolbarItemID.rectangle,
            ToolbarItemID.toggle
        ]
    }

    func toolbarDefaultItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [
        NSToolbarItem.Identifier
    ] {

        return [
            ToolbarItemID.undo,
            ToolbarItemID.redo,
            ToolbarItemID.flexible,
            ToolbarItemID.text,
            ToolbarItemID.rectangle,
            ToolbarItemID.toggle
        ]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier
            itemIdentifier:
                NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag:
            Bool
    ) -> NSToolbarItem? {

        switch itemIdentifier {

        case ToolbarItemID.undo:

            let item =
                NSToolbarItem(
                    itemIdentifier:
                        itemIdentifier
                )

            item.label =
                "Undo"

            item.paletteLabel =
                "Undo"

            item.toolTip =
                "Undo"

            item.image =
                NSImage(
                    systemSymbolName:
                        "arrow.uturn.backward",
                    accessibilityDescription:
                        "Undo"
                )

            item.target =
                self

            item.action =
                #selector(
                    undoAction
                )

            return item

        case ToolbarItemID.redo:

            let item =
                NSToolbarItem(
                    itemIdentifier:
                        itemIdentifier
                )

            item.label =
                "Redo"

            item.paletteLabel =
                "Redo"

            item.toolTip =
                "Redo"

            item.image =
                NSImage(
                    systemSymbolName:
                        "arrow.uturn.forward",
                    accessibilityDescription:
                        "Redo"
                )

            item.target =
                self

            item.action =
                #selector(
                    redoAction
                )

            return item

        case ToolbarItemID.text:

            let item =
                NSToolbarItem(
                    itemIdentifier:
                        itemIdentifier
                )

            item.label =
                "テキスト"

            item.paletteLabel =
                "テキスト"

            item.toolTip =
                "テキストを追加"

            item.image =
                NSImage(
                    systemSymbolName:
                        "textformat",
                    accessibilityDescription:
                        "Text"
                )

            item.target =
                self

            item.action =
                #selector(
                    addTextLayer
                )

            return item

        case ToolbarItemID.rectangle:

            let item =
                NSToolbarItem(
                    itemIdentifier:
                        itemIdentifier
                )

            item.label =
                "四角形"

            item.paletteLabel =
                "四角形"

            item.toolTip =
                "四角形を追加"

            item.image =
                NSImage(
                    systemSymbolName:
                        "square",
                    accessibilityDescription:
                        "Rectangle"
                )

            item.target =
                self

            item.action =
                #selector(
                    addRectangleLayer
                )

            return item

        case ToolbarItemID.toggle:

            let item =
                NSToolbarItem(
                    itemIdentifier:
                        itemIdentifier
                )

            item.label =
                "Switch"

            item.paletteLabel =
                "Switch"

            item.toolTip =
                "Switchを追加"

            item.image =
                NSImage(
                    systemSymbolName:
                        "switch.2",
                    accessibilityDescription:
                        "Switch"
                )

            item.target =
                self

            item.action =
                #selector(
                    addToggleLayer
                )

            return item

        default:

            return nil
        }
    }
}
