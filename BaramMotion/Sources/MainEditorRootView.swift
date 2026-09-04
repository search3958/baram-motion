import AppKit

final class MainEditorRootView: NSView {
    var onSpacePressed: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 && !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control) {
            onSpacePressed?()
            NSLog("[Baram Motion] Space key handled by editor root.")
            return
        }
        super.keyDown(with: event)
    }
}
