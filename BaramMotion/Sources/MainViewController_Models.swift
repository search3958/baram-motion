import AppKit

extension MainViewController {
    enum LayerKind: String {
        case text
        case rectangle
        case toggle
        var displayName: String {
            switch self {
            case .text: return "Text"
            case .rectangle: return "Rectangle"
            case .toggle: return "Switch"
            }
        }
    }

    enum PositionAnchor: Int {
        case topLeft = 0
        case center = 1
        var displayName: String {
            switch self {
            case .topLeft: return "左上から"
            case .center: return "中央から"
            }
        }
    }

    enum KeyframeEasing: String, CaseIterable {
        case linear = "Linear"
        case easeIn = "Ease In"
        case easeOut = "Ease Out"
        case easeInOut = "Ease In Out"
    }

    struct TransformValue: Equatable {
        var x: CGFloat
        var y: CGFloat
        var width: CGFloat
        var height: CGFloat
    }

    struct TransformKeyframe: Equatable {
        var frame: Int
        var x: CGFloat
        var y: CGFloat
        var width: CGFloat
        var height: CGFloat
        var easing: KeyframeEasing = .linear

        var value: TransformValue {
            TransformValue(x: x, y: y, width: width, height: height)
        }
    }

    enum BaramMotionTheme {
        static let windowBackground = NSColor.windowBackgroundColor
        static let pageBackground = NSColor.underPageBackgroundColor
        static let controlBackground = NSColor.controlBackgroundColor
        static let separator = NSColor.separatorColor
        static let primaryText = NSColor.labelColor
        static let secondaryText = NSColor.secondaryLabelColor
        static let tertiaryText = NSColor.tertiaryLabelColor
        static let accent = NSColor.controlAccentColor
        static let selectedBackground = NSColor.selectedContentBackgroundColor
        static let canvasBackground = NSColor.controlBackgroundColor
        static let timelineBackground = NSColor.controlBackgroundColor
        static let timelineAlternateBackground = NSColor.underPageBackgroundColor
        static let previewBackground = NSColor.black
    }

    final class LayerModel {
        let id: UUID
        var kind: LayerKind
        var name: String
        var color: NSColor
        var x: CGFloat
        var y: CGFloat
        var width: CGFloat
        var height: CGFloat
        var fontSize: CGFloat
        var anchor: PositionAnchor
        var startTime: CGFloat
        var duration: CGFloat
        var isOn: Bool
        var isVisible: Bool
        var keyframes: [TransformKeyframe]

        init(
            id: UUID = UUID(), kind: LayerKind, name: String, color: NSColor,
            x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
            fontSize: CGFloat = 56, anchor: PositionAnchor = .topLeft,
            startTime: CGFloat = 0, duration: CGFloat = 5, isOn: Bool = true,
            isVisible: Bool = true, keyframes: [TransformKeyframe] = []
        ) {
            self.id=id; self.kind=kind; self.name=name; self.color=color
            self.x=x; self.y=y; self.width=width; self.height=height
            self.fontSize=fontSize; self.anchor=anchor; self.startTime=startTime
            self.duration=duration; self.isOn=isOn; self.isVisible=isVisible
            self.keyframes=keyframes.sorted { $0.frame < $1.frame }
        }

        func currentTransform() -> TransformValue {
            TransformValue(x:x,y:y,width:width,height:height)
        }

        func copyLayer() -> LayerModel {
            LayerModel(id:id, kind:kind, name:name, color:color, x:x, y:y,
                       width:width, height:height, fontSize:fontSize, anchor:anchor,
                       startTime:startTime, duration:duration, isOn:isOn,
                       isVisible:isVisible, keyframes:keyframes)
        }
    }

    struct LayerSnapshot {
        let layer: LayerModel
        let order: Int
    }

    struct LayerModelProxy {
        let id: UUID
        let kindDisplayName: String
        let name: String
        let color: NSColor
        let startTime: CGFloat
        let duration: CGFloat
        let isVisible: Bool
        let keyframeFrames: [Int]
    }

    enum Layout {
        static let panelMargin: CGFloat = 16
        static let titlebarHeight: CGFloat = 56
        static let timelineHeight: CGFloat = 220
        static let floatingPanelWidth: CGFloat = 300
        static let floatingPanelMinimumWidth: CGFloat = 220
        static let floatingPanelTopMargin: CGFloat = 16
        static let floatingPanelBottomMargin: CGFloat = 16
        static let glassRadius: CGFloat = 18
        static let previewWidth: CGFloat = 1920
        static let previewHeight: CGFloat = 1080
        static let canvasWidth: CGFloat = 8000
        static let canvasHeight: CGFloat = 5000
        static let timelineScale: CGFloat = 90
        static let timelineLayerPanelWidth: CGFloat = 230
        static let minimumTimelineWidth: CGFloat = 3200
    }
}
