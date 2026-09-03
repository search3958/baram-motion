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
        _ id: UUID?
    ) {

        selectedLayerID =
            id

        refreshLayerList()
        refreshSelectionAppearance()
        rebuildInspector()
        refreshKeyframeInspector()

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

        layer.color =
            sender.color

        finishMutation(
            before: before,
            actionName: "カラー変更"
        )

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
    func positionFieldChanged(
        _ sender: NSTextField
    ) {

        guard let layer =
                selectedLayer else {

            NSLog(
                "[Baram Motion] ERROR: No selected layer for position change."
            )

            return
        }

        guard let value =
                Double(sender.stringValue),
              value.isFinite else {

            NSLog(
                "[Baram Motion] ERROR: Invalid position value."
            )

            refreshInspectorValues()

            return
        }

        let before =
            captureSnapshot()

        let targetFrame = playbackController.currentFrame
        if !layer.keyframes.isEmpty && layer.keyframes.firstIndex(where: { $0.frame == targetFrame }) == nil {
            let evaluated = evaluatedTransform(for: layer, frame: targetFrame)
            layer.keyframes.append(TransformKeyframe(frame: targetFrame, x: evaluated.x, y: evaluated.y, width: evaluated.width, height: evaluated.height))
            layer.keyframes.sort { $0.frame < $1.frame }
            NSLog("[Baram Motion] Auto-created transform keyframe at frame %d", targetFrame)
        }
        if let keyframeIndex = layer.keyframes.firstIndex(where: { $0.frame == targetFrame }) {
            if sender === xField { layer.keyframes[keyframeIndex].x = CGFloat(value) }
            if sender === yField { layer.keyframes[keyframeIndex].y = CGFloat(value) }
        } else {
            if sender === xField { layer.x = CGFloat(value) }
            if sender === yField { layer.y = CGFloat(value) }
            clampLayerPosition(layer)
        }

        finishMutation(
            before: before,
            actionName: "位置変更"
        )

        NSLog(
            "[Baram Motion] Position changed: %.1f, %.1f",
            layer.x,
            layer.y
        )
    }

    @objc
    func sizeFieldChanged(
        _ sender: NSTextField
    ) {

        guard let layer =
                selectedLayer else {

            NSLog(
                "[Baram Motion] ERROR: No selected layer for size change."
            )

            return
        }

        guard let value =
                Double(sender.stringValue),
              value.isFinite,
              value > 1 else {

            NSLog(
                "[Baram Motion] ERROR: Invalid size value."
            )

            refreshInspectorValues()

            return
        }

        let before =
            captureSnapshot()

        let targetFrame = playbackController.currentFrame
        if !layer.keyframes.isEmpty && layer.keyframes.firstIndex(where: { $0.frame == targetFrame }) == nil {
            let evaluated = evaluatedTransform(for: layer, frame: targetFrame)
            layer.keyframes.append(TransformKeyframe(frame: targetFrame, x: evaluated.x, y: evaluated.y, width: evaluated.width, height: evaluated.height))
            layer.keyframes.sort { $0.frame < $1.frame }
            NSLog("[Baram Motion] Auto-created transform keyframe at frame %d", targetFrame)
        }
        if let keyframeIndex = layer.keyframes.firstIndex(where: { $0.frame == targetFrame }) {
            if sender === widthField { layer.keyframes[keyframeIndex].width = max(1, CGFloat(value)) }
            if sender === heightField { layer.keyframes[keyframeIndex].height = max(1, CGFloat(value)) }
        } else {
            if sender === widthField { layer.width = CGFloat(value) }
            if sender === heightField { layer.height = CGFloat(value) }
            layer.width=max(1,layer.width); layer.height=max(1,layer.height); clampLayerPosition(layer)
        }

        finishMutation(
            before: before,
            actionName: "サイズ変更"
        )

        NSLog(
            "[Baram Motion] Size changed: %.1f x %.1f",
            layer.width,
            layer.height
        )
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

    func setSwitchState(
        for layerID: UUID,
        isOn: Bool
    ) {

        guard let layer = layers.first(where: { $0.id == layerID }) else {
            NSLog(
                "[Baram Motion] ERROR: SwiftUI Toggle layer not found: %@",
                layerID.uuidString
            )
            return
        }

        guard layer.kind == .toggle else {
            NSLog(
                "[Baram Motion] ERROR: SwiftUI Toggle target is not a switch: %@",
                layer.name
            )
            return
        }

        guard layer.isOn != isOn else {
            NSLog(
                "[Baram Motion] SwiftUI Toggle unchanged: %@",
                layer.name
            )
            return
        }

        let before = captureSnapshot()
        layer.isOn = isOn

        finishMutation(
            before: before,
            actionName: "Switch状態変更"
        )

        NSLog(
            "[Baram Motion] SwiftUI Toggle state changed %@: %@",
            layer.name,
            layer.isOn ? "ON" : "OFF"
        )
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

    func movePreviewLayer(
        _ id: UUID,
        deltaX: CGFloat,
        deltaY: CGFloat
    ) {
        guard let layer = layers.first(where: { $0.id == id }) else {
            NSLog("[Baram Motion] ERROR: Preview move layer not found.")
            return
        }

        if !layer.keyframes.isEmpty && !hasKeyframe(layer) {
            let evaluated=evaluatedTransform(for:layer,frame:playbackController.currentFrame)
            layer.keyframes.append(TransformKeyframe(frame:playbackController.currentFrame,x:evaluated.x,y:evaluated.y,width:evaluated.width,height:evaluated.height))
            layer.keyframes.sort{$0.frame<$1.frame}
            NSLog("[Baram Motion] Auto-created transform keyframe for preview drag at frame %d", playbackController.currentFrame)
        }
        if !layer.keyframes.isEmpty {
            guard let index=layer.keyframes.firstIndex(where:{$0.frame==playbackController.currentFrame}) else { return }
            layer.keyframes[index].x += deltaX
            layer.keyframes[index].y -= deltaY
            layer.keyframes[index].width=max(1,layer.keyframes[index].width)
            layer.keyframes[index].height=max(1,layer.keyframes[index].height)
        } else {
            layer.x += deltaX
            layer.y -= deltaY
            clampLayerPosition(layer)
        }

        refreshPreview()
        refreshInspectorValues()
        refreshKeyframeInspector()

        NSLog(
            "[Baram Motion] Preview position changed %@: x=%.1f y=%.1f",
            layer.name,
            layer.x,
            layer.y
        )
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
                left.anchor != right.anchor ||
                left.startTime != right.startTime ||
                left.duration != right.duration ||
                left.isOn != right.isOn ||
                left.isVisible != right.isVisible ||
                left.keyframes != right.keyframes {

                return true
            }
        }

        return false
    }
}
