import AppKit
import SwiftUI
import Combine

protocol TimelineContentViewDelegate:
    AnyObject {

    func timelineContentView(
        _ view:
            TimelineContentView,
        didSelectLayer id:
            UUID
    )

    func timelineContentView(
        _ view:
            TimelineContentView,
        didBeginEditingLayer id:
            UUID
    )

    func timelineContentView(
        _ view:
            TimelineContentView,
        didChangeLayer id:
            UUID,
        startTime:
            CGFloat,
        duration:
            CGFloat
    )

    func timelineContentView(
        _ view:
            TimelineContentView,
        didFinishEditingLayer id:
            UUID
    )
}

// MARK: - Timeline Content

final class TimelineContentView:
    NSView {

    weak var delegate:
        TimelineContentViewDelegate?

    private var layers:
        [MainViewController.LayerModelProxy]
        = []

    private var selectedLayerID:
        UUID?

    private let rulerHeight:
        CGFloat = 28

    private let rowHeight:
        CGFloat = 34

    private let timelineScale:
        CGFloat = 90

    private enum Interaction {
        case none
        case move
        case resizeLeft
        case resizeRight
    }

    private var interaction:
        Interaction = .none

    private var activeLayerID:
        UUID?

    private var dragStartMouseX:
        CGFloat = 0

    private var originalStartTime:
        CGFloat = 0

    private var originalDuration:
        CGFloat = 0

    var currentFrame: Int = 0

    private let edgeHitWidth:
        CGFloat = 8

    private let minimumDuration:
        CGFloat = 0.25

    override var isFlipped:
        Bool {
        return false
    }

    func reload(
        layers:
            [MainViewController.LayerModelProxy],
        selectedLayerID:
            UUID?
    ) {

        self.layers =
            layers

        self.selectedLayerID =
            selectedLayerID

        needsDisplay =
            true
    }

    override func draw(
        _ dirtyRect: NSRect
    ) {

        super.draw(
            dirtyRect
        )

        guard let context =
                NSGraphicsContext
                    .current?
                    .cgContext else {

            NSLog(
                "[Baram Motion] ERROR: Timeline graphics context is nil."
            )

            return
        }

        drawBackground()
        drawRuler(
            context
        )
        drawRows(
            context
        )
    }

    private func drawBackground() {

        NSColor.controlBackgroundColor.setFill()

        bounds.fill()
    }

    private func drawRuler(
        _ context:
            CGContext
    ) {

        let topY =
            bounds.height
            - rulerHeight

        NSColor.underPageBackgroundColor
            .setFill()

        NSRect(
            x: 0,
            y: topY,
            width: bounds.width,
            height: rulerHeight
        ).fill()

        NSColor.separatorColor
            .setStroke()

        context.setLineWidth(
            1
        )

        var second:
            CGFloat = 0

        while second
                * timelineScale
                < bounds.width {

            let x =
                second
                * timelineScale

            let isMajor =
                Int(second) % 5 == 0

            let markHeight:
                CGFloat =
                isMajor
                ? 14
                : 8

            context.move(
                to:
                    CGPoint(
                        x: x,
                        y: topY
                    )
            )

            context.addLine(
                to:
                    CGPoint(
                        x: x,
                        y:
                            topY
                            + markHeight
                    )
            )

            context.strokePath()

            if isMajor {

                let attributes:
                    [NSAttributedString.Key: Any] = [
                        .font:
                            NSFont.monospacedSystemFont(
                                ofSize: 10,
                                weight: .regular
                            ),

                        .foregroundColor:
                            NSColor.secondaryLabelColor
                    ]

                let label =
                    NSString(
                        string:
                            String(
                                format:
                                    "%.0fs",
                                Double(second)
                            )
                    )

                label.draw(
                    at:
                        NSPoint(
                            x:
                                x + 4,
                            y:
                                topY + 8
                        ),
                    withAttributes:
                        attributes
                )
            }

            second += 1
        }

        context.move(
            to:
                CGPoint(
                    x: 0,
                    y: topY
                )
        )

        context.addLine(
            to:
                CGPoint(
                    x: bounds.width,
                    y: topY
                )
        )

        context.strokePath()
    }

    private func drawRows(
        _ context:
            CGContext
    ) {

        let firstRowY =
            bounds.height
            - rulerHeight
            - rowHeight

        for index in layers.indices {

            let rowY =
                firstRowY
                - CGFloat(index)
                * rowHeight

            let rowRect =
                NSRect(
                    x: 0,
                    y: rowY,
                    width: bounds.width,
                    height: rowHeight
                )

            if index % 2 == 0 {

                NSColor.controlBackgroundColor
                    .setFill()

            } else {

                NSColor.underPageBackgroundColor
                    .setFill()
            }

            rowRect.fill()

            let layer =
                layers[index]

            let clipX =
                layer.startTime
                * timelineScale

            let clipWidth =
                max(
                    20,
                    layer.duration
                    * timelineScale
                )

            let clipRect =
                NSRect(
                    x: clipX,
                    y: rowY + 5,
                    width: clipWidth,
                    height: rowHeight - 10
                )

            let selected =
                layer.id
                == selectedLayerID

            let clipColor =
                layer.color.withAlphaComponent(
                    selected
                    ? 0.88
                    : 0.66
                )

            clipColor.setFill()

            let clipPath =
                NSBezierPath(
                    roundedRect:
                        clipRect,
                    xRadius:
                        6,
                    yRadius:
                        6
                )

            clipPath.fill()

            if selected {

                NSColor.controlAccentColor
                    .setStroke()

                clipPath.lineWidth =
                    2

                clipPath.stroke()
            }

            let title =
                NSString(
                    string:
                        "\(layer.kindDisplayName)  \(layer.name)"
                )

            let attributes:
                [NSAttributedString.Key: Any] = [
                    .font:
                        NSFont.systemFont(
                            ofSize: 11,
                            weight:
                                selected
                                ? .semibold
                                : .medium
                        ),

                    .foregroundColor:
                        NSColor.white
                ]

            title.draw(
                in:
                    clipRect.insetBy(
                        dx: 10,
                        dy: 6
                    ),
                withAttributes:
                    attributes
            )
        }

        let playheadX =
            CGFloat(currentFrame)
            / 30.0
            * timelineScale

        if playheadX >= 0 && playheadX <= bounds.width {
            NSColor.controlAccentColor.setStroke()
            context.setLineWidth(2)
            context.move(to: CGPoint(x: playheadX, y: 0))
            context.addLine(to: CGPoint(x: playheadX, y: bounds.height))
            context.strokePath()
        }
    }

    override func mouseDown(
        with event: NSEvent
    ) {

        let location =
            convert(
                event.locationInWindow,
                from: nil
            )

        guard let hit =
                hitTestLayer(
                    at: location
                ) else {

            interaction =
                .none

            activeLayerID =
                nil

            return
        }

        selectedLayerID =
            hit.layer.id

        delegate?.timelineContentView(
            self,
            didSelectLayer:
                hit.layer.id
        )

        activeLayerID =
            hit.layer.id

        dragStartMouseX =
            location.x

        originalStartTime =
            hit.layer.startTime

        originalDuration =
            hit.layer.duration

        let localX =
            location.x
            - hit.rect.minX

        if localX
                <= edgeHitWidth {

            interaction =
                .resizeLeft

        } else if localX
                    >= hit.rect.width
                    - edgeHitWidth {

            interaction =
                .resizeRight

        } else {

            interaction =
                .move
        }

        delegate?.timelineContentView(
            self,
            didBeginEditingLayer:
                hit.layer.id
        )

        NSLog(
            "[Baram Motion] Timeline editing started: %@",
            hit.layer.name
        )
    }

    override func mouseDragged(
        with event: NSEvent
    ) {

        guard interaction != .none,
              let activeLayerID,
              let active =
                layers.first(where: {
                    $0.id
                    == activeLayerID
                }) else {

            return
        }

        let location =
            convert(
                event.locationInWindow,
                from: nil
            )

        let deltaPixels =
            location.x
            - dragStartMouseX

        let rawDeltaTime =
            deltaPixels
            / timelineScale

        let deltaTime =
            round(rawDeltaTime * 30.0)
            / 30.0

        var newStart =
            originalStartTime

        var newDuration =
            originalDuration

        switch interaction {

        case .move:

            newStart =
                max(
                    0,
                    originalStartTime
                    + deltaTime
                )

        case .resizeLeft:

            let requestedStart =
                originalStartTime
                + deltaTime

            let maximumStart =
                originalStartTime
                + originalDuration
                - minimumDuration

            newStart =
                max(
                    0,
                    min(
                        maximumStart,
                        requestedStart
                    )
                )

            newDuration =
                originalDuration
                - (
                    newStart
                    - originalStartTime
                )

        case .resizeRight:

            newDuration =
                max(
                    minimumDuration,
                    originalDuration
                    + deltaTime
                )

        case .none:
            break
        }

        delegate?.timelineContentView(
            self,
            didChangeLayer:
                active.id,
            startTime:
                newStart,
            duration:
                newDuration
        )
    }

    override func mouseUp(
        with event: NSEvent
    ) {

        if let activeLayerID {

            delegate?.timelineContentView(
                self,
                didFinishEditingLayer:
                    activeLayerID
            )
        }

        interaction =
            .none

        activeLayerID =
            nil

        NSLog(
            "[Baram Motion] Timeline editing finished."
        )
    }

    private func hitTestLayer(
        at point:
            CGPoint
    ) -> (
        layer:
            MainViewController.LayerModelProxy,
        rect:
            NSRect
    )? {

        let firstRowY =
            bounds.height
            - rulerHeight
            - rowHeight

        for index in layers.indices {

            let rowY =
                firstRowY
                - CGFloat(index)
                * rowHeight

            let layer =
                layers[index]

            let rect =
                NSRect(
                    x:
                        layer.startTime
                        * timelineScale,
                    y:
                        rowY + 5,
                    width:
                        max(
                            20,
                            layer.duration
                            * timelineScale
                        ),
                    height:
                        rowHeight - 10
                )

            if rect.contains(point) {

                return (
                    layer:
                        layer,
                    rect:
                        rect
                )
            }
        }

        return nil
    }
}

// MARK: - Layer List Button
