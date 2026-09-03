import AppKit
import SwiftUI

final class PreviewElementView: NSView {

    let layerID: UUID
    let kind: MainViewController.LayerKind

    var backgroundColor: NSColor = .white {
        didSet { needsDisplay = true }
    }

    var fontSize: CGFloat = 48 {
        didSet { needsDisplay = true }
    }

    var text: String = "" {
        didSet { needsDisplay = true }
    }

    var isOn: Bool = true {
        didSet { updateSwitchView() }
    }

    var onSelect: ((UUID) -> Void)?
    var onBeginMove: ((UUID) -> Void)?
    var onMove: ((UUID, CGPoint) -> Void)?
    var onEndMove: ((UUID) -> Void)?
    var onToggleChanged: ((UUID, Bool) -> Void)?

    private var isMoving = false
    private var dragStartPoint = CGPoint.zero
    private var switchHostingView: NSHostingView<PreviewSwitchView>?

    init(layerID: UUID, kind: MainViewController.LayerKind) {
        self.layerID = layerID
        self.kind = kind
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 6
        translatesAutoresizingMaskIntoConstraints = false

        if kind == .toggle {
            let host = NSHostingView(rootView: makeSwitchView())
            host.translatesAutoresizingMaskIntoConstraints = true
            addSubview(host)
            switchHostingView = host
        }
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layout() {
        super.layout()
        switchHostingView?.frame = bounds
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard kind != .toggle else { return }

        switch kind {
        case .text:
            drawText()
        case .rectangle:
            drawRectangle()
        case .toggle:
            break
        }
    }

    private func drawText() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: backgroundColor
        ]

        let string = NSString(string: text)
        let size = string.size(withAttributes: attributes)
        let rect = NSRect(
            x: 0,
            y: max(0, (bounds.height - size.height) / 2),
            width: bounds.width,
            height: size.height
        )
        string.draw(in: rect, withAttributes: attributes)
    }

    private func drawRectangle() {
        backgroundColor.setFill()
        NSBezierPath(
            roundedRect: bounds,
            xRadius: 8,
            yRadius: 8
        ).fill()
    }

    func updateAppearance(selected: Bool) {
        layer?.borderWidth = selected ? 2 : 0
        layer?.borderColor = selected
            ? NSColor.controlAccentColor.cgColor
            : nil
        needsDisplay = true
    }

    private func makeSwitchView() -> PreviewSwitchView {
        PreviewSwitchView(
            isOn: Binding(
                get: { [weak self] in
                    guard let self else {
                        NSLog("[Baram Motion] ERROR: Preview switch owner released while reading state.")
                        return false
                    }
                    return self.isOn
                },
                set: { [weak self] value in
                    guard let self else {
                        NSLog("[Baram Motion] ERROR: Preview switch owner released while changing state.")
                        return
                    }
                    self.isOn = value
                    self.onToggleChanged?(self.layerID, value)
                    NSLog(
                        "[Baram Motion] Preview SwiftUI Toggle changed %@: %@",
                        self.layerID.uuidString,
                        value ? "ON" : "OFF"
                    )
                }
            ),
            onSelect: { [weak self] in
                guard let self else { return }
                self.onSelect?(self.layerID)
            },
            onBeginMove: { [weak self] in
                guard let self else { return }
                self.onBeginMove?(self.layerID)
            },
            onMove: { [weak self] delta in
                guard let self else { return }
                self.onMove?(self.layerID, delta)
            },
            onEndMove: { [weak self] in
                guard let self else { return }
                self.onEndMove?(self.layerID)
            }
        )
    }

    private func updateSwitchView() {
        guard kind == .toggle else {
            needsDisplay = true
            return
        }
        switchHostingView?.rootView = makeSwitchView()
        switchHostingView?.frame = bounds
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard kind != .toggle else {
            // The SwiftUI Toggle owns mouse interaction for switch layers.
            onSelect?(layerID)
            return
        }

        onSelect?(layerID)
        onBeginMove?(layerID)

        guard let superview else {
            NSLog("[Baram Motion] ERROR: Preview element has no superview.")
            return
        }

        dragStartPoint = superview.convert(event.locationInWindow, from: nil)
        isMoving = true

        NSLog(
            "[Baram Motion] Preview layer drag started: %@",
            layerID.uuidString
        )
    }

    override func mouseDragged(with event: NSEvent) {
        guard kind != .toggle,
              isMoving,
              let superview else {
            return
        }

        let currentPoint = superview.convert(event.locationInWindow, from: nil)
        let delta = CGPoint(
            x: currentPoint.x - dragStartPoint.x,
            y: currentPoint.y - dragStartPoint.y
        )
        dragStartPoint = currentPoint
        onMove?(layerID, delta)
    }

    override func mouseUp(with event: NSEvent) {
        guard kind != .toggle, isMoving else { return }
        isMoving = false
        onEndMove?(layerID)

        NSLog(
            "[Baram Motion] Preview layer drag finished: %@",
            layerID.uuidString
        )
    }
}

private final class PreviewSwitchDragState {
    var lastTranslation = CGSize.zero
}

private struct PreviewSwitchView: View {
    let isOn: Binding<Bool>
    let onSelect: () -> Void
    let onBeginMove: () -> Void
    let onMove: (CGPoint) -> Void
    let onEndMove: () -> Void

    private let dragState = PreviewSwitchDragState()

    var body: some View {
        Toggle("", isOn: isOn)
            .toggleStyle(.switch)
            .labelsHidden()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .simultaneousGesture(
                TapGesture().onEnded {
                    onSelect()
                }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        if dragState.lastTranslation == .zero {
                            onBeginMove()
                        }

                        let dx = value.translation.width - dragState.lastTranslation.width
                        let dy = value.translation.height - dragState.lastTranslation.height
                        dragState.lastTranslation = value.translation
                        onMove(CGPoint(x: dx, y: dy))
                    }
                    .onEnded { _ in
                        dragState.lastTranslation = .zero
                        onEndMove()
                    }
            )
            .accessibilityLabel("Switch")
    }
}
