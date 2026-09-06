import AppKit
import SwiftUI
import Combine

extension MainViewController {

    // MARK: - Selected Layer

    var selectedLayer: LayerModel? {

        guard let selectedLayerID else {
            return nil
        }

        return layers.first {
            $0.id == selectedLayerID
        }
    }

    func selectLayer(
        _ id: UUID?,
        shouldRefreshPreview: Bool = true
    ) {

        selectedLayerID =
            id

        refreshLayerList()
        refreshSelectionAppearance()
        rebuildInspector()
        refreshKeyframeInspector()

        if shouldRefreshPreview {
            refreshPreview()
        }

        timelineContent.reload(
            layers: timelineProxies,
            selectedLayerID: selectedLayerID
        )

        NSLog(
            "[Baram Motion] Selected layer: %@",
            id?.uuidString ?? "nil"
        )
    }

    // MARK: - Add Layers

    @objc
    func addTextLayer() {

        let before =
            captureSnapshot()

        let count =
            layers.filter {
                $0.kind == .text
            }.count + 1

        let layer =
            LayerModel(
                kind: .text,
                name: "Text \(count)",
                color: NSColor.white,
                text: "Text \(count)",
                x: 760,
                y: 430,
                width: 400,
                height: 90,
                fontSize: 56,
                anchor: .topLeft,
                startTime: 0,
                duration: 5
            )

        layers.append(layer)
        selectedLayerID = layer.id

        finishMutation(
            before: before,
            actionName: "テキスト追加"
        )

        NSLog(
            "[Baram Motion] Text layer added: %@",
            layer.name
        )
    }

    @objc
    func addRectangleLayer() {

        let before =
            captureSnapshot()

        let count =
            layers.filter {
                $0.kind == .rectangle
            }.count + 1

        let layer =
            LayerModel(
                kind: .rectangle,
                name: "Rectangle \(count)",
                color: NSColor.systemBlue,
                x: 750,
                y: 380,
                width: 420,
                height: 240,
                anchor: .topLeft,
                startTime: 0,
                duration: 5
            )

        layers.append(layer)
        selectedLayerID = layer.id

        finishMutation(
            before: before,
            actionName: "四角形追加"
        )

        NSLog(
            "[Baram Motion] Rectangle layer added: %@",
            layer.name
        )
    }

    @objc
    func addToggleLayer() {

        let before =
            captureSnapshot()

        let count =
            layers.filter {
                $0.kind == .toggle
            }.count + 1

        let layer =
            LayerModel(
                kind: .toggle,
                name: "Switch \(count)",
                color: NSColor.systemBlue,
                x: 850,
                y: 420,
                width: 180,
                height: 100,
                anchor: .topLeft,
                startTime: 0,
                duration: 5,
                isOn: true
            )

        layers.append(layer)
        selectedLayerID = layer.id

        finishMutation(
            before: before,
            actionName: "Switch追加"
        )

        NSLog(
            "[Baram Motion] Switch layer added: %@",
            layer.name
        )
    }

    @objc
    func deleteSelectedLayer() {

        guard let selectedLayerID else {

            NSLog(
                "[Baram Motion] WARNING: No layer selected for deletion."
            )

            return
        }

        guard layers.contains(where: {
            $0.id == selectedLayerID
        }) else {

            NSLog(
                "[Baram Motion] ERROR: Selected layer no longer exists."
            )

            return
        }

        let before =
            captureSnapshot()

        layers.removeAll {
            $0.id == selectedLayerID
        }

        self.selectedLayerID =
            layers.last?.id

        finishMutation(
            before: before,
            actionName: "レイヤー削除"
        )

        NSLog(
            "[Baram Motion] Layer deleted: %@",
            selectedLayerID.uuidString
        )
    }

    // MARK: - Undo / Redo

    @objc
    func undoAction() {

        guard let manager =
                view.window?.undoManager,
              manager.canUndo else {

            NSLog(
                "[Baram Motion] Undo unavailable."
            )

            return
        }

        manager.undo()

        NSLog(
            "[Baram Motion] Undo executed."
        )
    }

    @objc
    func redoAction() {

        guard let manager =
                view.window?.undoManager,
              manager.canRedo else {

            NSLog(
                "[Baram Motion] Redo unavailable."
            )

            return
        }

        manager.redo()

        NSLog(
            "[Baram Motion] Redo executed."
        )
    }

    // MARK: - Inspector Changes

    @objc
    func colorChanged(
        _ sender: NSColorWell
    ) {

        guard let layer =
                selectedLayer else {

            NSLog(
                "[Baram Motion] ERROR: No selected layer for color change."
            )

            return
        }

        let before =
            captureSnapshot()

        let frame = playbackController.currentFrame
        if let idx = layer.propertyKeyframes.firstIndex(where: { $0.property == .color && $0.frame == frame }) {
            let cv = ColorValue.from(sender.color)
            layer.propertyKeyframes[idx].colorValue = cv
            layer.propertyKeyframes[idx].scalar = cv.brightness
        } else if layer.propertyKeyframes.contains(where: { $0.property == .color }) {
            layer.propertyKeyframes.append(.color(frame, value: ColorValue.from(sender.color)))
            normalizeKeyframes(layer)
        } else {
            layer.color = sender.color
        }

        finishMutation(before: before, actionName: "カラー変更")

        NSLog(
            "[Baram Motion] Color changed."
        )
    }

    @objc
    func anchorChanged(
        _ sender: NSPopUpButton
    ) {

        guard let layer =
                selectedLayer else {

            NSLog(
                "[Baram Motion] ERROR: No selected layer for anchor change."
            )

            return
        }

        let newAnchor:
            PositionAnchor =
            sender.indexOfSelectedItem
                == PositionAnchor.center.rawValue
                ? .center
                : .topLeft

        guard layer.anchor != newAnchor else {
            return
        }

        let before =
            captureSnapshot()

        let currentFrame =
            frameForLayer(layer)

        layer.anchor =
            newAnchor

        let newPosition =
            positionForFrame(
                currentFrame,
                anchor: newAnchor
            )

        layer.x =
            newPosition.x

        layer.y =
            newPosition.y

        clampLayerPosition(layer)

        finishMutation(
            before: before,
            actionName: "基準位置変更"
        )

        NSLog(
            "[Baram Motion] Anchor changed: %@",
            newAnchor.displayName
        )
    }

    @objc
    func positionFieldChanged(_ sender: NSTextField) {
        guard let layer = selectedLayer else { NSLog("[Baram Motion] ERROR: No selected layer for position change."); return }
        guard let number = Double(sender.stringValue), number.isFinite else { NSLog("[Baram Motion] ERROR: Invalid position value."); refreshInspectorValues(); return }
        let property: AnimatedProperty = sender === xField ? .x : .y
        let before = captureSnapshot()
        let frame = playbackController.currentFrame
        if let idx = layer.propertyKeyframes.firstIndex(where: { $0.property == property && $0.frame == frame }) {
            layer.propertyKeyframes[idx].scalar = CGFloat(number)
        } else if layer.propertyKeyframes.contains(where: { $0.property == property }) {
            layer.propertyKeyframes.append(.scalar(property, frame: frame, value: CGFloat(number)))
        } else {
            if property == .x { layer.x = CGFloat(number) } else { layer.y = CGFloat(number) }
            clampLayerPosition(layer)
        }
        finishMutation(before: before, actionName: "\(property.rawValue) 変更")
        NSLog("[Baram Motion] Position property changed %@ frame=%d", property.rawValue, frame)
    }

    @objc
    func sizeFieldChanged(_ sender: NSTextField) {
        guard let layer = selectedLayer else { NSLog("[Baram Motion] ERROR: No selected layer for size change."); return }
        guard let number = Double(sender.stringValue), number.isFinite, number > 0 else { NSLog("[Baram Motion] ERROR: Invalid size value."); refreshInspectorValues(); return }
        let property: AnimatedProperty = sender === heightField ? .height : .width
        let value = max(1, CGFloat(number))
        let before = captureSnapshot()
        let frame = playbackController.currentFrame
        if let idx = layer.propertyKeyframes.firstIndex(where: { $0.property == property && $0.frame == frame }) {
            layer.propertyKeyframes[idx].scalar = value
        } else if layer.propertyKeyframes.contains(where: { $0.property == property }) {
            layer.propertyKeyframes.append(.scalar(property, frame: frame, value: value))
        } else if property == .width {
            layer.width = value
            clampLayerPosition(layer)
        } else {
            layer.height = value
            clampLayerPosition(layer)
        }
        finishMutation(before: before, actionName: "\(property.rawValue) 変更")
        NSLog("[Baram Motion] Size property changed %@ frame=%d value=%.1f", property.rawValue, frame, value)
    }

    @objc
    func fontSizeChanged(
        _ sender: NSTextField
    ) {

        guard let layer =
                selectedLayer,
              layer.kind == .text else {

            NSLog(
                "[Baram Motion] ERROR: Invalid text layer for font change."
            )

            return
        }

        guard let value =
                Double(sender.stringValue),
              value.isFinite,
              value > 1 else {

            NSLog(
                "[Baram Motion] ERROR: Invalid font size."
            )

            refreshInspectorValues()

            return
        }

        let before =
            captureSnapshot()

        layer.fontSize =
            max(
                1,
                CGFloat(value)
            )

        finishMutation(
            before: before,
            actionName: "文字サイズ変更"
        )

        NSLog(
            "[Baram Motion] Font size changed: %.1f",
            layer.fontSize
        )
    }

    @objc func textContentChanged(_ sender: NSTextField) {
        guard let layer = selectedLayer, layer.kind == .text else { return }
        let before = captureSnapshot()
        let frame = playbackController.currentFrame
        if let idx = layer.propertyKeyframes.firstIndex(where: { $0.property == .text && $0.frame == frame }) {
            layer.propertyKeyframes[idx].text = sender.stringValue
        } else if layer.propertyKeyframes.contains(where: { $0.property == .text }) {
            layer.propertyKeyframes.append(.text(frame, value: sender.stringValue))
        } else {
            layer.text = sender.stringValue
        }
        layer.propertyKeyframes.sort { $0.frame == $1.frame ? $0.property.rawValue < $1.property.rawValue : $0.frame < $1.frame }
        finishMutation(before: before, actionName: "テキスト変更")
        NSLog("[Baram Motion] Text changed at frame %d: %@", frame, sender.stringValue)
    }

    @objc func transformFieldChanged(_ sender: NSTextField) {
        guard let layer = selectedLayer else { return }
        guard let number = Double(sender.stringValue), number.isFinite else { return }
        let property: AnimatedProperty = sender === scaleXField ? .scaleX : sender === scaleYField ? .scaleY : .rotation
        let before = captureSnapshot()
        let frame = playbackController.currentFrame
        if let idx = layer.propertyKeyframes.firstIndex(where: { $0.property == property && $0.frame == frame }) {
            layer.propertyKeyframes[idx].scalar = CGFloat(number)
        } else if layer.propertyKeyframes.contains(where: { $0.property == property }) {
            layer.propertyKeyframes.append(.scalar(property, frame: frame, value: CGFloat(number)))
        }
        normalizeKeyframes(layer)
        finishMutation(before: before, actionName: "\(property.rawValue) 変更")
    }

    @objc func fontChanged(_ sender: NSPopUpButton) {
        guard let layer = selectedLayer, layer.kind == .text else { return }
        let before = captureSnapshot()
        let frame = playbackController.currentFrame
        if let idx = layer.propertyKeyframes.firstIndex(where: { $0.property == .font && $0.frame == frame }) {
            layer.propertyKeyframes[idx].fontName = sender.titleOfSelectedItem ?? ""
        } else if layer.propertyKeyframes.contains(where: { $0.property == .font }) {
            if let idx = layer.propertyKeyframes.firstIndex(where: { $0.property == .font }) {
                layer.propertyKeyframes[idx].fontName = sender.titleOfSelectedItem ?? ""
            }
        } else if layer.propertyKeyframes.contains(where: { $0.property == .text && $0.frame == frame }) {
            if let idx = layer.propertyKeyframes.firstIndex(where: { $0.property == .text && $0.frame == frame }) {
                layer.propertyKeyframes[idx].fontName = sender.titleOfSelectedItem ?? ""
            }
        } else {
            layer.propertyKeyframes.append(.font(frame, value: sender.titleOfSelectedItem ?? ""))
            normalizeKeyframes(layer)
        }
        finishMutation(before: before, actionName: "フォント変更")
    }

    func setSwitchState(for id: UUID, isOn: Bool) {
        guard let layer = layers.first(where: { $0.id == id }), layer.kind == .toggle else {
            NSLog("[Baram Motion] ERROR: Switch layer not found."); return
        }
        guard evaluatedSwitchState(for: layer, frame: playbackController.currentFrame) != isOn else { return }
        let before = captureSnapshot()
        let frame = playbackController.currentFrame
        if let idx = layer.propertyKeyframes.firstIndex(where: { $0.property == .isOn && $0.frame == frame }) {
            layer.propertyKeyframes[idx].boolValue = isOn
        } else if layer.propertyKeyframes.contains(where: { $0.property == .isOn }) {
            layer.propertyKeyframes.append(.state(frame, value: isOn))
        } else {
            layer.isOn = isOn
        }
        layer.propertyKeyframes.sort { $0.frame == $1.frame ? $0.property.rawValue < $1.property.rawValue : $0.frame < $1.frame }
        finishMutation(before: before, actionName: "Switch状態変更")
        NSLog("[Baram Motion] Switch state changed: %@ frame=%d state=%@", layer.name, frame, isOn ? "ON" : "OFF")
    }

    // MARK: - Playback

    var timelineEndTime: CGFloat {
        max(
            1,
            layers.reduce(CGFloat(0)) {
                max($0, $1.startTime + $1.duration)
            }
        )
    }

    var totalPlaybackFrames: Int {
        max(1, Int(ceil(Double(timelineEndTime * playbackFrameRate))))
    }

    func refreshPlaybackUI() {
        let frameCount = totalPlaybackFrames
        playbackLastFrameCount = frameCount
        playbackController.setTotalFrames(frameCount)

        let clamped = min(playbackController.currentFrame, frameCount)
        if playbackController.currentFrame != clamped {
            playbackController.setCurrentFrame(clamped, notify: false)
        }

        timelineContent.currentFrame = playbackController.currentFrame
        timelineContent.needsDisplay = true
    }

    func playbackFrameChanged(_ frame: Int) {
        let clamped = max(0, min(totalPlaybackFrames, frame))
        playbackController.setCurrentFrame(clamped, notify: false)
        timelineContent.currentFrame = clamped
        timelineContent.needsDisplay = true
        refreshPreview()
        refreshInspectorValues()
        refreshKeyframeInspector()

        let time = CGFloat(clamped) / playbackFrameRate
        NSLog(
            "[Baram Motion] Playback position: frame %d / %d (%.3fs)",
            clamped,
            totalPlaybackFrames,
            Double(time)
        )
    }

    // MARK: - Preview Position Editing

    func beginPreviewLayerEditing(_ id: UUID) {
        guard let layer = layers.first(where: { $0.id == id }) else {
            NSLog("[Baram Motion] ERROR: Preview edit layer not found.")
            return
        }

        previewEditingLayerID = id
        previewEditBeforeSnapshot = captureSnapshot()

        NSLog(
            "[Baram Motion] Preview position edit begin: %@",
            layer.name
        )
    }

    func movePreviewLayer(_ id: UUID, deltaX: CGFloat, deltaY: CGFloat) {
        guard let layer = layers.first(where: { $0.id == id }) else { NSLog("[Baram Motion] ERROR: Preview move layer not found."); return }
        let frame = playbackController.currentFrame
        let animatedX = layer.propertyKeyframes.contains(where: { $0.property == .x })
        let animatedY = layer.propertyKeyframes.contains(where: { $0.property == .y })
        if animatedX || animatedY {
            if let idx = layer.propertyKeyframes.firstIndex(where: { $0.property == .x && $0.frame == frame }) { layer.propertyKeyframes[idx].scalar += deltaX }
            else { layer.propertyKeyframes.append(.scalar(.x, frame: frame, value: evaluatedTransform(for: layer, frame: frame).x + deltaX)) }
            if let idx = layer.propertyKeyframes.firstIndex(where: { $0.property == .y && $0.frame == frame }) { layer.propertyKeyframes[idx].scalar -= deltaY }
            else { layer.propertyKeyframes.append(.scalar(.y, frame: frame, value: evaluatedTransform(for: layer, frame: frame).y - deltaY)) }
            layer.propertyKeyframes.sort { $0.frame == $1.frame ? $0.property.rawValue < $1.property.rawValue : $0.frame < $1.frame }
        } else {
            layer.x += deltaX; layer.y -= deltaY; clampLayerPosition(layer)
        }
        if let element = previewElementViews[id] {
            let displayLayer = layer.copyLayer()
            let transform = evaluatedTransform(for: layer, frame: frame)
            displayLayer.x = transform.x; displayLayer.y = transform.y
            displayLayer.width = max(1, transform.width); displayLayer.height = max(1, transform.height)
            displayLayer.cornerRadius = evaluatedCornerRadius(for: layer, frame: frame)
            element.frame = frameForLayer(displayLayer)
            element.cornerRadius = min(displayLayer.cornerRadius, min(displayLayer.width, displayLayer.height) * 0.5)
        }
        refreshInspectorValues()
        refreshKeyframeInspector()
        NSLog("[Baram Motion] Preview position changed %@ frame=%d", layer.name, frame)
    }

    func finishPreviewLayerEditing(_ id: UUID) {
        guard let before = previewEditBeforeSnapshot[id],
              let after = layers.first(where: { $0.id == id })?.copyLayer() else {
            previewEditBeforeSnapshot.removeAll()
            previewEditingLayerID = nil
            return
        }

        if before.layer.x != after.x || before.layer.y != after.y {
            registerUndo(
                before: previewEditBeforeSnapshot,
                actionName: "プレビュー位置変更"
            )
            NSLog(
                "[Baram Motion] Preview position edit registered: %@",
                after.name
            )
        }

        previewEditBeforeSnapshot.removeAll()
        previewEditingLayerID = nil
    }

    // MARK: - Undo Snapshot

    func captureSnapshot()
        -> [UUID: LayerSnapshot] {

        var result:
            [UUID: LayerSnapshot] = [:]

        for layer in layers {

            result[layer.id] =
                LayerSnapshot(
                    layer: layer.copyLayer(),
                    order: layers.firstIndex(where: { $0.id == layer.id }) ?? 0
                )
        }

        return result
    }

    func finishMutation(
        before:
            [UUID: LayerSnapshot],
        actionName: String
    ) {

        guard !isRestoringUndoState else {

            refreshAll()

            return
        }

        let after =
            captureSnapshot()

        guard snapshotsDiffer(
            before,
            after
        ) else {

            refreshAll()

            return
        }

        registerUndo(
            before: before,
            actionName: actionName
        )

        refreshAll()
    }

    func registerUndo(
        before:
            [UUID: LayerSnapshot],
        actionName: String
    ) {

        guard let manager =
                view.window?.undoManager else {

            NSLog(
                "[Baram Motion] WARNING: Undo manager unavailable."
            )

            return
        }

        manager.registerUndo(
            withTarget: self
        ) { [weak self] target in

            guard let self else {
                return
            }

            let current =
                self.captureSnapshot()

            self.restoreSnapshots(
                before
            )

            self.registerUndo(
                before: current,
                actionName: actionName
            )

            self.refreshAll()
        }

        manager.setActionName(
            actionName
        )
    }

    func restoreSnapshots(
        _ snapshots:
            [UUID: LayerSnapshot]
    ) {

        isRestoringUndoState = true

        defer {
            isRestoringUndoState = false
        }

        let restoredLayers = snapshots.values
            .sorted { $0.order < $1.order }
            .map { $0.layer.copyLayer() }

        layers = restoredLayers

        if let selectedLayerID,
           !layers.contains(where: {
               $0.id == selectedLayerID
           }) {

            self.selectedLayerID =
                layers.last?.id
        }
    }

    func snapshotsDiffer(
        _ lhs:
            [UUID: LayerSnapshot],
        _ rhs:
            [UUID: LayerSnapshot]
    ) -> Bool {

        if lhs.count != rhs.count {
            return true
        }

        for id in lhs.keys {

            guard let left =
                    lhs[id]?.layer,
                  let right =
                    rhs[id]?.layer else {

                return true
            }

            if left.kind != right.kind ||
                left.name != right.name ||
                !left.color.isEqual(
                    right.color
                ) ||
                left.x != right.x ||
                left.y != right.y ||
                left.width != right.width ||
                left.height != right.height ||
                left.fontSize != right.fontSize ||
                left.fontName != right.fontName ||
                left.anchor != right.anchor ||
                left.startTime != right.startTime ||
                left.duration != right.duration ||
                left.isOn != right.isOn ||
                left.isVisible != right.isVisible ||
                left.opacity != right.opacity ||
                left.propertyKeyframes != right.propertyKeyframes {

                return true
            }
        }

        return false
    }
}
