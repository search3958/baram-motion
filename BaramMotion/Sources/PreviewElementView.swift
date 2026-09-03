import AppKit
import SwiftUI

final class PreviewElementView: NSView {
    let layerID: UUID
    let kind: MainViewController.LayerKind
    var backgroundColor: NSColor  =  .white { didSet { needsDisplay  =  true; updateSwitchView() } }
    var fontSize: CGFloat  =  48 { didSet { needsDisplay  =  true } }
    var text: String  =  "" { didSet { needsDisplay  =  true } }
    var isOn: Bool  =  true { didSet { updateSwitchView() } }
    var switchTint: Color  =  .accentColor { didSet { updateSwitchView() } }

    var onSelect: ((UUID) -> Void)?
    var onBeginMove: ((UUID) -> Void)?
    var onMove: ((UUID, CGPoint) -> Void)?
    var onEndMove: ((UUID) -> Void)?
    var onToggleChanged: ((UUID, Bool) -> Void)?

    private var isMoving  =  false
    private var dragStartPoint  =  CGPoint.zero
    private var switchHostingView: NSHostingView<PreviewSwitchView>?

    init(layerID: UUID, kind: MainViewController.LayerKind) {
        self.layerID = layerID; self.kind = kind
        super.init(frame:.zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        translatesAutoresizingMaskIntoConstraints = false
        if kind == .toggle {
            let host = NSHostingView(rootView: makeSwitchView())
            host.translatesAutoresizingMaskIntoConstraints = true
            addSubview(host); switchHostingView = host
        }
    }
    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        guard let host = switchHostingView else { return }
        // Native switch aspect ratio (~1.65:1), fitted into requested layer bounds.
        let ratio: CGFloat  =  1.65
        let fittedWidth = min(bounds.width, bounds.height*ratio)
        let fittedHeight = fittedWidth/ratio
        host.frame = NSRect(x:(bounds.width-fittedWidth)/2, y:(bounds.height-fittedHeight)/2,
                          width:fittedWidth, height:fittedHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard kind != .toggle else { return }
        switch kind {
        case .text:
            let attrs:[NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:fontSize,weight:.medium),.foregroundColor:backgroundColor]
            NSString(string:text).draw(in: bounds.insetBy(dx:2,dy:0), withAttributes:attrs)
        case .rectangle:
            backgroundColor.setFill()
            NSBezierPath(roundedRect:bounds,xRadius:8,yRadius:8).fill()
        case .toggle: break
        }
    }

    func updateAppearance(selected: Bool) {
        layer?.borderWidth = selected ? 2 : 0
        layer?.borderColor = selected ? NSColor.controlAccentColor.cgColor : nil
    }

    private func makeSwitchView() -> PreviewSwitchView {
        PreviewSwitchView(
            isOn: Binding(get:{ [weak self] in self?.isOn ?? false }, set:{ [weak self] value in
                guard let self else { NSLog("[Baram Motion] ERROR: Switch owner released."); return }
                self.isOn = value; self.onToggleChanged?(self.layerID,value)
                NSLog("[Baram Motion] Preview SwiftUI Toggle changed %@", self.layerID.uuidString)
            }),
            tint: switchTint,
            onSelect:{ [weak self] in guard let self else{return}; self.onSelect?(self.layerID) },
            onBeginMove:{ [weak self] in guard let self else{return}; self.onBeginMove?(self.layerID) },
            onMove:{ [weak self] delta in guard let self else{return}; self.onMove?(self.layerID,delta) },
            onEndMove:{ [weak self] in guard let self else{return}; self.onEndMove?(self.layerID) }
        )
    }

    private func updateSwitchView() {
        guard kind == .toggle, let host = switchHostingView else { needsDisplay = true; return }
        host.rootView = makeSwitchView(); needsLayout = true
    }

    override func mouseDown(with event:NSEvent) {
        onSelect?(layerID)
        onBeginMove?(layerID)
        guard let superview else { NSLog("[Baram Motion] ERROR: Preview element has no superview."); return }
        dragStartPoint = superview.convert(event.locationInWindow,from:nil); isMoving = true
    }
    override func mouseDragged(with event:NSEvent) {
        guard isMoving, let superview else{return}
        let current = superview.convert(event.locationInWindow,from:nil)
        let delta = CGPoint(x:current.x-dragStartPoint.x,y:current.y-dragStartPoint.y)
        dragStartPoint = current; onMove?(layerID,delta)
    }
    override func mouseUp(with event:NSEvent) {
        guard isMoving else{return}; isMoving = false; onEndMove?(layerID)
    }
}

private final class PreviewSwitchGestureState { var last  =  CGSize.zero }

private struct PreviewSwitchView: View {
    let isOn: Binding<Bool>
    let tint: Color
    let onSelect: () -> Void
    let onBeginMove: () -> Void
    let onMove: (CGPoint) -> Void
    let onEndMove: () -> Void

    private let gestureState  =  PreviewSwitchGestureState()

    var body: some View {
        Toggle("", isOn: isOn)
            .toggleStyle(.switch)
            .tint(tint)
            .labelsHidden()
            .frame(maxWidth:.infinity,maxHeight:.infinity)
            .simultaneousGesture(TapGesture().onEnded{ onSelect() })
            .simultaneousGesture(DragGesture(minimumDistance:4).onChanged{ value in
                if gestureState.last == .zero { onBeginMove() }
                onMove(CGPoint(x:value.translation.width-gestureState.last.width,y:value.translation.height-gestureState.last.height))
                gestureState.last = value.translation
            }.onEnded{ _ in gestureState.last = .zero; onEndMove() })
    }
}

