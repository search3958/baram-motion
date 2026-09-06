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

    override func draw(_ dirtyRect:NSRect){
        super.draw(dirtyRect)
        guard kind != .toggle else { return }
        switch kind {
        case .rectangle:
            layer?.backgroundColor = backgroundColor.cgColor
            applyContinuousCornerRadius()
            let strokeRect=bounds.insetBy(dx:borderInsetForStroke,dy:borderInsetForStroke)
            let r=min(cornerRadius,strokeRect.width*0.5,strokeRect.height*0.5)
            let path=NSBezierPath(roundedRect:strokeRect,xRadius:r,yRadius:r)
            drawStroke(path)
        case .text:
            let font=NSFontManager.shared.font(withFamily:fontName,traits:[],weight:5,size:fontSize) ?? NSFont(name:fontName,size:fontSize) ?? NSFont.systemFont(ofSize:fontSize,weight:.medium)
            let style=NSMutableParagraphStyle(); style.alignment=textHorizontalAlignment.nsAlignment; style.lineBreakMode = .byWordWrapping
            let attrs:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:backgroundColor,.paragraphStyle:style]
            let textRect=bounds.insetBy(dx:borderInsetForFill,dy:borderInsetForFill)
            let attr=NSAttributedString(string:text,attributes:attrs)
            let used=attr.boundingRect(with:NSSize(width:max(1,textRect.width),height:.greatestFiniteMagnitude),options:[.usesLineFragmentOrigin,.usesFontLeading])
            let y:CGFloat
            switch textVerticalAlignment { case .top: y=textRect.maxY-used.height; case .center: y=textRect.midY-used.height*0.5; case .bottom: y=textRect.minY }
            attr.draw(in:NSRect(x:textRect.minX,y:y,width:textRect.width,height:min(textRect.height,max(used.height,textRect.height))))
            let strokeRect=bounds.insetBy(dx:borderInsetForStroke,dy:borderInsetForStroke)
            let path=NSBezierPath(rect:strokeRect); drawStroke(path)
        case .toggle: break
        }
    }

    private var borderInsetForFill:CGFloat { borderPosition == .inside ? borderWidth : borderPosition == .centered ? borderWidth*0.5 : 0 }
    private var borderInsetForStroke:CGFloat { borderPosition == .inside ? borderWidth*0.5 : borderPosition == .centered ? 0 : -borderWidth*0.5 }
    private func drawStroke(_ path:NSBezierPath){ guard borderWidth>0 else{return}; borderColor.setStroke(); path.lineWidth=borderWidth; path.stroke() }
    private func applyContinuousCornerRadius(){ guard let l=layer else{return}; l.cornerCurve = .continuous; l.cornerRadius=max(0,min(cornerRadius,min(bounds.width,bounds.height)*0.5)) }
    private func applyBorder(){ guard let l=layer else{return}; l.cornerCurve = .continuous; l.borderWidth = 0 }
    private func applyPresentationTransform(){ layer?.setAffineTransform(CGAffineTransform(rotationAngle: rotation * .pi / 180).scaledBy(x:max(0.001,scaleX),y:max(0.001,scaleY))) }
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
