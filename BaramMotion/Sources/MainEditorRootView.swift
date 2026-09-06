import AppKit

final class MainEditorRootView: NSView {
    var onSpacePressed: (() -> Void)?
    var onUndoPressed: (() -> Void)?
    var onRedoPressed: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isZ = event.charactersIgnoringModifiers?.lowercased() == "z" || event.keyCode == 6
        let hasUndoModifier = flags.contains(.command) || flags.contains(.control)

        if isZ && hasUndoModifier {
            if flags.contains(.shift) {
                onRedoPressed?()
                NSLog("[Baram Motion] Redo shortcut handled: Ctrl/Command+Shift+Z")
            } else {
                onUndoPressed?()
                NSLog("[Baram Motion] Undo shortcut handled: Ctrl/Command+Z")
            }
            return
        }

        if event.keyCode == 49 && !flags.contains(.command) && !flags.contains(.control) {
            onSpacePressed?()
            NSLog("[Baram Motion] Space key handled by editor root.")
            return
        }
        super.keyDown(with: event)
    }
}
