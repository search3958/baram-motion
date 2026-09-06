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

    enum PositionAnchor: Int, CaseIterable {
        case topLeft = 0, top = 1, topRight = 2
        case left = 3, center = 4, right = 5
        case bottomLeft = 6, bottom = 7, bottomRight = 8
        var displayName: String {
            switch self {
            case .topLeft: return "左上"
            case .top: return "上"
            case .topRight: return "右上"
            case .left: return "左"
            case .center: return "中央"
            case .right: return "右"
            case .bottomLeft: return "左下"
            case .bottom: return "下"
            case .bottomRight: return "右下"
            }
        }
    }

    enum StrokePosition: Int, CaseIterable {
        case inside = 0, centered = 1, outside = 2
        var displayName: String {
            switch self {
            case .inside: return "内側"
            case .centered: return "間"
            case .outside: return "外側"
            }
        }
    }

    enum TextHorizontalAlignment: Int, CaseIterable {
        case left = 0, center = 1, right = 2
        var nsAlignment: NSTextAlignment { switch self { case .left: return .left; case .center: return .center; case .right: return .right } }
        var displayName: String { switch self { case .left: return "左"; case .center: return "中央"; case .right: return "右" } }
    }

    enum TextVerticalAlignment: Int, CaseIterable {
        case top = 0, center = 1, bottom = 2
        var displayName: String { switch self { case .top: return "上"; case .center: return "中央"; case .bottom: return "下" } }
    }

    struct CubicBezier: Equatable {
        var cp1: CGPoint
        var cp2: CGPoint

        static let linear = CubicBezier(cp1: CGPoint(x: 0, y: 0), cp2: CGPoint(x: 1, y: 1))
        static let easeIn = CubicBezier(cp1: CGPoint(x: 0.42, y: 0), cp2: CGPoint(x: 1, y: 1))
        static let easeOut = CubicBezier(cp1: CGPoint(x: 0, y: 0), cp2: CGPoint(x: 0.58, y: 1))
        static let easeInOut = CubicBezier(cp1: CGPoint(x: 0.42, y: 0), cp2: CGPoint(x: 0.58, y: 1))

        static let presets: [(String, CubicBezier)] = [
            ("Linear", .linear),
            ("Ease In", .easeIn),
            ("Ease Out", .easeOut),
            ("Ease In Out", .easeInOut),
        ]

        func evaluate(_ t: CGFloat) -> CGFloat {
            let u = 1 - t
            let tt = t * t
            let uu = u * u
            return 3 * uu * t * cp1.y + 3 * u * tt * cp2.y + t * t * t
        }

        func xAt(_ t: CGFloat) -> CGFloat {
            let u = 1 - t
            let tt = t * t
            let uu = u * u
            return 3 * uu * t * cp1.x + 3 * u * tt * cp2.x + t * t * t
        }

        func xDerivative(_ t: CGFloat) -> CGFloat {
            let u = 1 - t
            return 3 * u * u * cp1.x + 6 * u * t * (cp2.x - cp1.x) + 3 * t * t * (1 - cp2.x)
        }

        func solve(_ value: CGFloat) -> CGFloat {
            var t = value
            for _ in 0..<10 {
                let x = xAt(t)
                let dx = xDerivative(t)
                if abs(dx) < 0.0001 { break }
                let diff = x - value
                if abs(diff) < 0.0001 { break }
                t -= diff / dx
                t = max(0, min(1, t))
            }
            return evaluate(t)
        }
    }

    struct TransformValue: Equatable {
        var x: CGFloat
        var y: CGFloat
        var width: CGFloat
        var height: CGFloat
        var scaleX: CGFloat
        var scaleY: CGFloat
        var rotation: CGFloat
    }

    struct ColorValue: Equatable {
        var r: CGFloat
        var g: CGFloat
        var b: CGFloat
        var a: CGFloat

        func nsColor() -> NSColor { NSColor(calibratedRed: r, green: g, blue: b, alpha: a) }
        var brightness: CGFloat { max(0, min(1, 0.2126*r + 0.7152*g + 0.0722*b)) }
        static func from(_ color: NSColor) -> ColorValue {
            let c = color.usingColorSpace(.deviceRGB) ?? color.usingColorSpace(.sRGB) ?? color
            return ColorValue(r: c.redComponent, g: c.greenComponent, b: c.blueComponent, a: c.alphaComponent)
        }
    }

    enum AnimatedProperty: String, CaseIterable {
        case x = "X"
        case y = "Y"
        case width = "幅"
        case height = "高さ"
        case scaleX = "Xスケール"
        case scaleY = "Yスケール"
        case rotation = "角度"
        case opacity = "透明度"
        case cornerRadius = "角丸"
        case borderWidth = "枠線太さ"
        case borderColor = "枠線カラー"
        case color = "カラー"
        case text = "テキスト"
        case font = "フォント"
        case isOn = "Switch状態"

        var isNumeric: Bool {
            switch self {
            case .x, .y, .width, .height, .scaleX, .scaleY, .rotation, .opacity, .cornerRadius, .borderWidth, .color: return true
            case .borderColor, .text, .font, .isOn: return false
            }
        }
    }

    struct PropertyKeyframe: Equatable {
        var frame: Int
        var property: AnimatedProperty
        var scalar: CGFloat
        var text: String
        var fontName: String
        var boolValue: Bool
        var colorValue: ColorValue?
        var easing: CubicBezier = .easeInOut

        static func scalar(_ property: AnimatedProperty, frame: Int, value: CGFloat, easing: CubicBezier = .easeInOut) -> PropertyKeyframe {
            PropertyKeyframe(frame: frame, property: property, scalar: value, text: "", fontName: "", boolValue: false, colorValue: nil, easing: easing)
        }

        static func text(_ frame: Int, value: String, easing: CubicBezier = .easeInOut) -> PropertyKeyframe {
            PropertyKeyframe(frame: frame, property: .text, scalar: 0, text: value, fontName: "", boolValue: false, colorValue: nil, easing: easing)
        }

        static func state(_ frame: Int, value: Bool, easing: CubicBezier = .easeInOut) -> PropertyKeyframe {
            PropertyKeyframe(frame: frame, property: .isOn, scalar: 0, text: "", fontName: "", boolValue: value, colorValue: nil, easing: easing)
        }

        static func color(_ frame: Int, value: ColorValue, easing: CubicBezier = .easeInOut) -> PropertyKeyframe {
            PropertyKeyframe(frame: frame, property: .color, scalar: value.brightness, text: "", fontName: "", boolValue: false, colorValue: value, easing: easing)
        }

        static func font(_ frame: Int, value: String, easing: CubicBezier = .easeInOut) -> PropertyKeyframe {
            PropertyKeyframe(frame: frame, property: .font, scalar: 0, text: "", fontName: value, boolValue: false, colorValue: nil, easing: easing)
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
        static let graphX = NSColor.systemRed
        static let graphY = NSColor.systemGreen
        static let graphWidth = NSColor.systemBlue
        static let graphHeight = NSColor.systemOrange
        static let graphCornerRadius = NSColor.systemPurple
        static let graphColor = NSColor.systemTeal
        static let graphText = NSColor.systemPink
        static let graphSwitch = NSColor.systemYellow
    }

    final class LayerModel {
        let id: UUID
        var kind: LayerKind
        var name: String
        var color: NSColor
        var opacity: CGFloat
        var borderWidth: CGFloat
        var borderColor: NSColor
        var borderPosition: StrokePosition
        var textHorizontalAlignment: TextHorizontalAlignment
        var textVerticalAlignment: TextVerticalAlignment
        var text: String
        var x: CGFloat
        var y: CGFloat
        var width: CGFloat
        var height: CGFloat
        var baseScaleX: CGFloat
        var baseScaleY: CGFloat
        var baseRotation: CGFloat
        var cornerRadius: CGFloat
        var fontSize: CGFloat
        var fontName: String
        var anchor: PositionAnchor
        var startTime: CGFloat
        var duration: CGFloat
        var isOn: Bool
        var isVisible: Bool
        var propertyKeyframes: [PropertyKeyframe]

        init(
            id: UUID = UUID(), kind: LayerKind, name: String, color: NSColor, text: String? = nil,
            opacity: CGFloat = 1, borderWidth: CGFloat = 0, borderColor: NSColor = .labelColor, borderPosition: StrokePosition = .centered,
            textHorizontalAlignment: TextHorizontalAlignment = .center, textVerticalAlignment: TextVerticalAlignment = .center,
            x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
            scaleX: CGFloat = 1, scaleY: CGFloat = 1, rotation: CGFloat = 0,
            cornerRadius: CGFloat = 8,
            fontSize: CGFloat = 56, fontName: String = NSFont.systemFont(ofSize: 56, weight: .medium).familyName ?? NSFont.systemFont(ofSize: 56).fontName, anchor: PositionAnchor = .topLeft,
            startTime: CGFloat = 0, duration: CGFloat = 5, isOn: Bool = true,
            isVisible: Bool = true, propertyKeyframes: [PropertyKeyframe] = []
        ) {
            self.id=id; self.kind=kind; self.name=name; self.color=color
            self.opacity=max(0,min(1,opacity)); self.borderWidth=max(0,borderWidth); self.borderColor=borderColor; self.borderPosition=borderPosition
            self.textHorizontalAlignment=textHorizontalAlignment; self.textVerticalAlignment=textVerticalAlignment
            self.text=text ?? (kind == .text ? name : "")
            self.x=x; self.y=y; self.width=width; self.height=height
            self.baseScaleX=max(0.001,scaleX); self.baseScaleY=max(0.001,scaleY); self.baseRotation=rotation
            self.cornerRadius=max(0,cornerRadius)
            self.fontSize=fontSize; self.fontName=fontName; self.anchor=anchor; self.startTime=startTime
            self.duration=duration; self.isOn=isOn; self.isVisible=isVisible
            self.propertyKeyframes = propertyKeyframes.sorted { $0.frame == $1.frame ? $0.property.rawValue < $1.property.rawValue : $0.frame < $1.frame }
        }

        // Base transform values are persistent non-keyframed values.
        // Keep the legacy property names as compatibility accessors so existing code can be evolved incrementally.
        var scaleX: CGFloat {
            get { baseScaleX }
            set { baseScaleX = max(0.001, newValue) }
        }

        var scaleY: CGFloat {
            get { baseScaleY }
            set { baseScaleY = max(0.001, newValue) }
        }

        var rotation: CGFloat {
            get { baseRotation }
            set { baseRotation = newValue }
        }

        func currentTransform() -> TransformValue {
            TransformValue(x:x,y:y,width:width,height:height,scaleX:baseScaleX,scaleY:baseScaleY,rotation:baseRotation)
        }

        func copyLayer() -> LayerModel {
            LayerModel(id:id, kind:kind, name:name, color:color, text:text, opacity:opacity, borderWidth:borderWidth, borderColor:borderColor, borderPosition:borderPosition,
                       textHorizontalAlignment:textHorizontalAlignment, textVerticalAlignment:textVerticalAlignment, x:x, y:y, width:width, height:height,
                       scaleX:scaleX, scaleY:scaleY, rotation:rotation, cornerRadius:cornerRadius, fontSize:fontSize, fontName:fontName, anchor:anchor,
                       startTime:startTime, duration:duration, isOn:isOn,
                       isVisible:isVisible, propertyKeyframes:propertyKeyframes)
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
