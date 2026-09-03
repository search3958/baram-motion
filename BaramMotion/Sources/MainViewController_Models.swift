import AppKit

extension MainViewController {

    // MARK: - Layer Types

    enum LayerKind: String {
        case text
        case rectangle
        case toggle

        var displayName: String {
            switch self {
            case .text:
                return "Text"
            case .rectangle:
                return "Rectangle"
            case .toggle:
                return "Switch"
            }
        }
    }

    enum PositionAnchor: Int {
        case topLeft = 0
        case center = 1

        var displayName: String {
            switch self {
            case .topLeft:
                return "左上から"
            case .center:
                return "中央から"
            }
        }
    }

    // MARK: - Theme

    enum BaramMotionTheme {

        // Window / panels
        static let windowBackground =
            NSColor.windowBackgroundColor

        static let pageBackground =
            NSColor.underPageBackgroundColor

        static let controlBackground =
            NSColor.controlBackgroundColor

        static let separator =
            NSColor.separatorColor

        // Text
        static let primaryText =
            NSColor.labelColor

        static let secondaryText =
            NSColor.secondaryLabelColor

        static let tertiaryText =
            NSColor.tertiaryLabelColor

        // Accent
        static let accent =
            NSColor.controlAccentColor

        static let selectedBackground =
            NSColor.selectedContentBackgroundColor

        // Editor canvas
        static let canvasBackground =
            NSColor.controlBackgroundColor

        static let timelineBackground =
            NSColor.controlBackgroundColor

        static let timelineAlternateBackground =
            NSColor.underPageBackgroundColor

        // Preview itself is intentionally black.
        static let previewBackground =
            NSColor.black
    }

    // MARK: - Layer Model

    final class LayerModel {

        let id: UUID

        var kind: LayerKind
        var name: String

        var color: NSColor

        // Position in 1920x1080 Preview coordinates.
        // Origin is interpreted according to anchor.
        var x: CGFloat
        var y: CGFloat

        var width: CGFloat
        var height: CGFloat

        var fontSize: CGFloat

        var anchor: PositionAnchor

        // Timeline
        var startTime: CGFloat
        var duration: CGFloat

        // Switch only
        var isOn: Bool

        init(
            id: UUID = UUID(),
            kind: LayerKind,
            name: String,
            color: NSColor,
            x: CGFloat,
            y: CGFloat,
            width: CGFloat,
            height: CGFloat,
            fontSize: CGFloat = 56,
            anchor: PositionAnchor = .topLeft,
            startTime: CGFloat = 0,
            duration: CGFloat = 5,
            isOn: Bool = true
        ) {
            self.id = id
            self.kind = kind
            self.name = name
            self.color = color
            self.x = x
            self.y = y
            self.width = width
            self.height = height
            self.fontSize = fontSize
            self.anchor = anchor
            self.startTime = startTime
            self.duration = duration
            self.isOn = isOn
        }

        func copyLayer() -> LayerModel {
            return LayerModel(
                id: id,
                kind: kind,
                name: name,
                color: color,
                x: x,
                y: y,
                width: width,
                height: height,
                fontSize: fontSize,
                anchor: anchor,
                startTime: startTime,
                duration: duration,
                isOn: isOn
            )
        }
    }

    struct LayerSnapshot {
        let layer: LayerModel
    }

    struct LayerModelProxy {
        let id: UUID
        let kindDisplayName: String
        let name: String
        let color: NSColor
        let startTime: CGFloat
        let duration: CGFloat
    }

    // MARK: - Layout

    enum Layout {

        static let panelMargin: CGFloat = 16

        static let titlebarHeight: CGFloat = 56

        static let timelineHeight: CGFloat = 170

        static let floatingPanelWidth: CGFloat = 300
        static let floatingPanelMinimumWidth: CGFloat = 220

        static let floatingPanelTopMargin: CGFloat = 16
        static let floatingPanelBottomMargin: CGFloat = 16

        static let glassRadius: CGFloat = 18

        // Preview
        static let previewWidth: CGFloat = 1920
        static let previewHeight: CGFloat = 1080

        // Large editor canvas
        static let canvasWidth: CGFloat = 8000
        static let canvasHeight: CGFloat = 5000

        // Timeline
        static let timelineScale: CGFloat = 90
        static let minimumTimelineWidth: CGFloat = 3200
    }
}
