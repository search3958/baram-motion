import AppKit

// MARK: - Timeline Delegate

extension MainViewController:
    TimelineContentViewDelegate {

    func timelineContentView(
        _ view: TimelineContentView,
        didSelectLayer id: UUID
    ) {

        selectLayer(id)
    }

    func timelineContentView(
        _ view: TimelineContentView,
        didBeginEditingLayer id: UUID
    ) {

        guard let layer =
                layers.first(where: {
                    $0.id == id
                }) else {

            NSLog(
                "[Baram Motion] ERROR: Timeline edit layer not found."
            )

            return
        }

        timelineEditBeforeSnapshot = [
            id:
                LayerSnapshot(
                    layer:
                        layer.copyLayer()
                )
        ]

        NSLog(
            "[Baram Motion] Timeline edit begin: %@",
            layer.name
        )
    }

    func timelineContentView(
        _ view: TimelineContentView,
        didChangeLayer id: UUID,
        startTime: CGFloat,
        duration: CGFloat
    ) {

        guard let layer =
                layers.first(where: {
                    $0.id == id
                }) else {

            NSLog(
                "[Baram Motion] ERROR: Timeline layer not found."
            )

            return
        }

        layer.startTime =
            max(
                0,
                startTime
            )

        layer.duration =
            max(
                0.25,
                duration
            )

        updateTimelineSize()
        refreshPreview()

        timelineContent.reload(
            layers:
                timelineProxies,
            selectedLayerID:
                selectedLayerID
        )

        NSLog(
            "[Baram Motion] Timeline changed %@: start %.2f / duration %.2f",
            layer.name,
            layer.startTime,
            layer.duration
        )
    }

    func timelineContentView(
        _ view: TimelineContentView,
        didFinishEditingLayer id: UUID
    ) {

        guard !timelineEditBeforeSnapshot.isEmpty else {
            return
        }

        let current =
            captureSnapshot()

        var changed =
            false

        for (id, before)
            in timelineEditBeforeSnapshot {

            guard let after =
                    current[id]?.layer else {

                changed = true
                break
            }

            if before.layer.startTime
                    != after.startTime
                ||
                before.layer.duration
                    != after.duration {

                changed = true
                break
            }
        }

        if changed {

            registerUndo(
                before:
                    timelineEditBeforeSnapshot,
                actionName:
                    "タイムライン編集"
            )
        }

        timelineEditBeforeSnapshot.removeAll()

        refreshAll()

        NSLog(
            "[Baram Motion] Timeline edit finished."
        )
    }
}

// MARK: - Preview Scroll View

