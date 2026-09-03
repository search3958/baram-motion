import AppKit

extension MainViewController: TimelineContentViewDelegate {
    func timelineContentView(_ view: TimelineContentView, didSelectLayer id: UUID) { selectLayer(id) }

    func timelineContentView(_ view: TimelineContentView, didBeginEditingLayer id: UUID) {
    guard layers.contains(where: { $0.id == id }) else {
        NSLog("[Baram Motion] ERROR: Timeline edit layer not found.")
        return
    }

    timelineEditBeforeSnapshot = captureSnapshot()
    NSLog("[Baram Motion] Timeline editing began: \(id)")
}

    func timelineContentView(_ view: TimelineContentView, didChangeLayer id: UUID, startTime: CGFloat, duration: CGFloat) {
        guard let layer=layers.first(where:{$0.id==id}) else { NSLog("[Baram Motion] ERROR: Timeline layer not found."); return }
        layer.startTime=max(0,startTime); layer.duration=max(1.0/30.0,duration)
        updateTimelineSize(); refreshPreview()
        timelineContent.reload(layers:timelineProxies,selectedLayerID:selectedLayerID)
        timelineLayerPanel?.reload(layers:timelineProxies,selectedLayerID:selectedLayerID)
        syncTimelineLayerPanelScroll()
    }

    func timelineContentView(_ view: TimelineContentView, didFinishEditingLayer id: UUID) {
        guard !timelineEditBeforeSnapshot.isEmpty else { return }
        let current=captureSnapshot(); var changed=false
        for (id,before) in timelineEditBeforeSnapshot {
            guard let after=current[id]?.layer else { changed=true; break }
            if before.layer.startTime != after.startTime || before.layer.duration != after.duration { changed=true; break }
        }
        if changed { registerUndo(before:timelineEditBeforeSnapshot,actionName:"タイムライン編集") }
        timelineEditBeforeSnapshot.removeAll(); refreshAll()
    }

    func timelineContentView(_ view: TimelineContentView, didRequestFrame frame: Int) { playbackFrameChanged(frame) }

    func timelineContentView(_ view: TimelineContentView, didRequestAddKeyframe layerID: UUID, frame: Int) {
        guard let layer=layers.first(where:{$0.id==layerID}) else { NSLog("[Baram Motion] ERROR: Timeline keyframe layer not found."); return }
        let before=captureSnapshot()
        if let index=layer.keyframes.firstIndex(where:{$0.frame==frame}) { layer.keyframes.remove(at:index) }
        else { let t=evaluatedTransform(for:layer,frame:frame); layer.keyframes.append(TransformKeyframe(frame:frame,x:t.x,y:t.y,width:t.width,height:t.height)); layer.keyframes.sort{$0.frame<$1.frame} }
        playbackFrameChanged(frame); finishMutation(before:before,actionName:"キーフレーム変更")
    }
}

extension MainViewController: TimelineLayerPanelViewDelegate {
    func timelineLayerPanel(_ view: TimelineLayerPanelView, didSelectLayer id: UUID) { selectLayer(id) }
    func timelineLayerPanel(_ view: TimelineLayerPanelView, didBeginMovingLayer id: UUID) {
        timelineOrderBeforeSnapshot = captureSnapshot()
    }
    func timelineLayerPanel(_ view: TimelineLayerPanelView, didToggleVisibility id: UUID) {
        guard let layer=layers.first(where:{$0.id==id}) else { NSLog("[Baram Motion] ERROR: Visibility layer not found."); return }
        let before=captureSnapshot(); layer.isVisible.toggle(); finishMutation(before:before,actionName:"レイヤー表示切替")
    }
    func timelineLayerPanel(_ view: TimelineLayerPanelView, didMoveLayer id: UUID, toIndex index: Int) {
        guard let source=layers.firstIndex(where:{$0.id==id}), !layers.isEmpty else{return}
        let target=max(0,min(index,layers.count-1)); guard source != target else{return}
        let moving=layers.remove(at:source); layers.insert(moving,at:target)
        refreshAll()
    }

    func timelineLayerPanel(_ view: TimelineLayerPanelView, didFinishMovingLayer id: UUID) {
        guard !timelineOrderBeforeSnapshot.isEmpty else{return}
        let current=captureSnapshot()
        if snapshotsDiffer(timelineOrderBeforeSnapshot,current) { registerUndo(before:timelineOrderBeforeSnapshot,actionName:"レイヤー順変更") }
        timelineOrderBeforeSnapshot.removeAll(); refreshAll()
    }
}
