import AppKit
import SwiftUI

final class PreviewElementView: NSView {
    let layerID: UUID
    let kind: MainViewController.LayerKind
    var backgroundColor: NSColor = .white { didSet { needsDisplay=true; updateSwitchView() } }
    var fontSize: CGFloat = 48 { didSet { needsDisplay=true } }
    var fontName: String = NSFont.systemFont(ofSize:48,weight:.medium).fontName { didSet { needsDisplay=true } }
    var text: String = "" { didSet { needsDisplay=true } }
    var textHorizontalAlignment: MainViewController.TextHorizontalAlignment = .center { didSet { needsDisplay=true } }
    var textVerticalAlignment: MainViewController.TextVerticalAlignment = .center { didSet { needsDisplay=true } }
    var scaleX: CGFloat = 1 { didSet { applyPresentationTransform() } }
    var scaleY: CGFloat = 1 { didSet { applyPresentationTransform() } }
    var rotation: CGFloat = 0 { didSet { applyPresentationTransform() } }
    var opacity: CGFloat = 1 { didSet { layer?.opacity=Float(max(0,min(1,opacity))) } }
    var isOn: Bool = true { didSet { updateSwitchView() } }
    var switchTint: Color = .accentColor { didSet { updateSwitchView() } }
    var cornerRadius: CGFloat = 8 { didSet { applyContinuousCornerRadius(); needsDisplay=true } }
    var borderWidth: CGFloat = 0 { didSet { needsDisplay=true; applyBorder() } }
    var borderColor: NSColor = .labelColor { didSet { applyBorder() } }
    var borderPosition: MainViewController.StrokePosition = .centered { didSet { needsDisplay=true; applyBorder() } }

    var onSelect: ((UUID)->Void)?
    var onBeginMove: ((UUID)->Void)?
    var onMove: ((UUID,CGPoint)->Void)?
    var onEndMove: ((UUID)->Void)?
    var onToggleChanged: ((UUID,Bool)->Void)?

    private var isMoving=false
    private var dragStartPoint=CGPoint.zero
    private var switchHostingView:NSHostingView<PreviewSwitchView>?

    init(layerID:UUID,kind:MainViewController.LayerKind){
        self.layerID=layerID; self.kind=kind
        super.init(frame:.zero)
        wantsLayer=true; layer?.masksToBounds=false; layer?.cornerCurve = .continuous
        if kind == .toggle { let host=NSHostingView(rootView:makeSwitchView()); host.autoresizingMask=[.width,.height]; addSubview(host); switchHostingView=host }
    }
    required init?(coder:NSCoder){nil}

    override func layout(){
        super.layout(); applyContinuousCornerRadius(); applyBorder(); layer?.opacity=Float(max(0,min(1,opacity)))
        guard let host=switchHostingView else{return}
        let ratio:CGFloat=1.65; let fw=min(bounds.width,bounds.height*ratio), fh=fw/ratio
        host.frame=NSRect(x:(bounds.width-fw)/2,y:(bounds.height-fh)/2,width:fw,height:fh)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard kind != .toggle else { return }

        switch kind {
        case .rectangle:
            drawRectangleElement()
        case .text:
            drawTextElement()
        case .toggle:
            break
        }
    }

    private func drawRectangleElement() {
        guard bounds.width > 0, bounds.height > 0 else {
            NSLog("[Baram Motion] WARNING: Rectangle bounds are empty.")
            return
        }

        layer?.backgroundColor = nil

        if borderPosition == .outside, borderWidth > 0 {
            // Keep the complete outside border inside this view's drawable area.
            // The border is painted first and the element fill is inset over it.
            borderColor.setFill()
            roundedPath(inset: 0).fill()
            backgroundColor.setFill()
            roundedPath(inset: borderWidth).fill()
            return
        }

        let fillPath = roundedPath(inset: 0)
        let strokePath: NSBezierPath?
        switch borderPosition {
        case .inside:
            strokePath = borderWidth > 0 ? roundedPath(inset: borderWidth * 0.5) : nil
        case .centered:
            strokePath = borderWidth > 0 ? roundedPath(inset: 0) : nil
        case .outside:
            strokePath = nil
        }

        backgroundColor.setFill()
        fillPath.fill()

        if let strokePath {
            drawStroke(strokePath)
        }
    }

    private func roundedPath(inset: CGFloat) -> NSBezierPath {
        let maximumInset = max(0, min(bounds.width, bounds.height) * 0.5 - 0.5)
        let safeInset = max(0, min(inset, maximumInset))
        let rect = bounds.insetBy(dx: safeInset, dy: safeInset)
        let radius = max(0, min(cornerRadius - safeInset, rect.width * 0.5, rect.height * 0.5))
        return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    }

    private func drawTextElement() {
        guard !text.isEmpty, bounds.width > 0, bounds.height > 0 else {
            if text.isEmpty { NSLog("[Baram Motion] INFO: Text element is empty.") }
            return
        }

        let font = NSFontManager.shared.font(withFamily: fontName, traits: [], weight: 5, size: fontSize)
            ?? NSFont(name: fontName, size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let style = NSMutableParagraphStyle()
        style.alignment = textHorizontalAlignment.nsAlignment
        style.lineBreakMode = .byWordWrapping

        let contentInset: CGFloat = borderPosition == .inside ? borderWidth : borderPosition == .centered ? borderWidth * 0.5 : 0
        let textRect = bounds.insetBy(dx: contentInset, dy: contentInset)
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: style
        ]
        let measure = NSAttributedString(string: text, attributes: baseAttributes)
        let used = measure.boundingRect(
            with: NSSize(width: max(1, textRect.width), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let drawY: CGFloat
        switch textVerticalAlignment {
        case .top: drawY = textRect.maxY - used.height
        case .center: drawY = textRect.midY - used.height * 0.5
        case .bottom: drawY = textRect.minY
        }
        let drawRect = NSRect(
            x: textRect.minX,
            y: drawY,
            width: textRect.width,
            height: min(textRect.height, max(used.height, textRect.height))
        )

        let normalizedFontSize = max(fontSize, 1)
        let strokePercent = max(0, borderWidth * 100 / normalizedFontSize)
        let fillAttributes = baseAttributes.merging([.foregroundColor: backgroundColor]) { _, new in new }

        guard borderWidth > 0, strokePercent > 0 else {
            NSAttributedString(string: text, attributes: fillAttributes).draw(in: drawRect)
            return
        }

        switch borderPosition {
        case .outside:
            // Positive strokeWidth is outline-only. Draw it first, then paint the normal glyph fill over it.
            let outlineAttributes = baseAttributes.merging([
                .strokeWidth: strokePercent,
                .strokeColor: borderColor
            ]) { _, new in new }
            NSAttributedString(string: text, attributes: outlineAttributes).draw(in: drawRect)
            NSAttributedString(string: text, attributes: fillAttributes).draw(in: drawRect)
        case .inside, .centered:
            // Negative strokeWidth keeps the glyph fill. Drawing after the fill keeps the outline visible above it.
            var stroked = fillAttributes
            stroked[.strokeWidth] = -strokePercent
            stroked[.strokeColor] = borderColor
            NSAttributedString(string: text, attributes: stroked).draw(in: drawRect)
        }
    }

    private func drawStroke(_ path: NSBezierPath) {
        guard borderWidth > 0 else { return }
        borderColor.setStroke()
        path.lineWidth = borderWidth
        path.stroke()
    }

    private func applyContinuousCornerRadius(){ guard let l=layer else{return}; l.cornerCurve = .continuous; l.cornerRadius=max(0,min(cornerRadius,min(bounds.width,bounds.height)*0.5)) }
    private func applyBorder(){ guard let l=layer else{return}; l.cornerCurve = .continuous; l.borderWidth = 0 }
    private func applyPresentationTransform(){
        guard let presentationLayer = layer else {
            NSLog("[Baram Motion] ERROR: Preview element has no backing layer for transform: %@", layerID.uuidString)
            return
        }

        let safeScaleX = max(0.001, scaleX)
        let safeScaleY = max(0.001, scaleY)
        let radians = rotation * .pi / 180
        var transform = CGAffineTransform.identity
        transform = transform.scaledBy(x: safeScaleX, y: safeScaleY)
        transform = transform.rotated(by: radians)

        // Apply immediately and synchronously; implicit animations would make the
        // inspector/playback appear one or more frames behind the model.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        presentationLayer.setAffineTransform(transform)
        CATransaction.commit()
        needsDisplay = true
        NSLog("[Baram Motion] Presentation transform applied: layer=%@ scaleX=%.3f scaleY=%.3f rotation=%.3f",
              layerID.uuidString, Double(safeScaleX), Double(safeScaleY), Double(rotation))
    }
    func applyFrameForExportIfNeeded() {
        // Reapply without animation immediately before a frame is captured.
        // This guarantees the exported bitmap sees the exact transform used in
        // the editor, even when Core Animation has not committed a previous change.
        applyPresentationTransform()
        needsDisplay = true
    }

    func updateAppearance(selected:Bool){ layer?.borderWidth = selected ? 2 : 0; layer?.borderColor = selected ? NSColor.controlAccentColor.cgColor : nil }

    private func makeSwitchView()->PreviewSwitchView{ PreviewSwitchView(isOn:Binding(get:{[weak self] in self?.isOn ?? false},set:{[weak self] v in guard let self else{return}; self.isOn=v; self.onToggleChanged?(self.layerID,v)}),tint:switchTint,onSelect:{[weak self] in self?.onSelect?(self!.layerID)},onBeginMove:{[weak self] in self?.onBeginMove?(self!.layerID)},onMove:{[weak self] d in self?.onMove?(self!.layerID,d)},onEndMove:{[weak self] in self?.onEndMove?(self!.layerID)}) }
    private func updateSwitchView(){ guard kind == .toggle, let host=switchHostingView else{needsDisplay=true;return}; host.rootView=makeSwitchView() }

    override func mouseDown(with event:NSEvent){ onSelect?(layerID); onBeginMove?(layerID); guard let sv=superview else{NSLog("[Baram Motion] ERROR: Preview element has no superview.");return}; dragStartPoint=sv.convert(event.locationInWindow,from:nil);isMoving=true }
    override func mouseDragged(with event:NSEvent){ guard isMoving,let sv=superview else{return}; let cur=sv.convert(event.locationInWindow,from:nil); let d=CGPoint(x:cur.x-dragStartPoint.x,y:cur.y-dragStartPoint.y);dragStartPoint=cur;onMove?(layerID,d) }
    override func mouseUp(with event:NSEvent){ guard isMoving else{return};isMoving=false;onEndMove?(layerID) }
}

private final class PreviewSwitchGestureState { var last=CGSize.zero }
private struct PreviewSwitchView: View {
    let isOn:Binding<Bool>; let tint:Color; let onSelect:()->Void; let onBeginMove:()->Void; let onMove:(CGPoint)->Void; let onEndMove:()->Void
    private let gestureState=PreviewSwitchGestureState()
    var body:some View{ GeometryReader{proxy in let bw:CGFloat=52; let bh:CGFloat=32; let scale=min(max(proxy.size.width/bw,0.01),max(proxy.size.height/bh,0.01)); Toggle("",isOn:isOn).toggleStyle(.switch).tint(tint).labelsHidden().frame(width:bw,height:bh).scaleEffect(scale).frame(maxWidth:.infinity,maxHeight:.infinity).contentShape(Rectangle()).simultaneousGesture(TapGesture().onEnded{onSelect()}).simultaneousGesture(DragGesture(minimumDistance:4).onChanged{v in if gestureState.last == .zero{onBeginMove()};onMove(CGPoint(x:v.translation.width-gestureState.last.width,y:v.translation.height-gestureState.last.height));gestureState.last=v.translation}.onEnded{_ in gestureState.last = .zero;onEndMove()}) } }
}
