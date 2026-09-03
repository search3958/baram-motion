import AppKit
import SwiftUI
import Combine

final class PreviewScrollView:
    NSScrollView {

    private var didInitialPosition =
        false

    override func viewDidMoveToWindow() {

        super.viewDidMoveToWindow()

        guard window != nil else {
            return
        }

        positionCanvasInitially()
    }

    override func layout() {

        super.layout()

        positionCanvasInitially()
    }

    private func positionCanvasInitially() {

        guard !didInitialPosition else {
            return
        }

        guard let documentView else {

            NSLog(
                "[Baram Motion] ERROR: Preview documentView is nil."
            )

            return
        }

        let bounds =
            contentView.bounds

        guard bounds.width > 0,
              bounds.height > 0 else {
            return
        }

        let documentFrame =
            documentView.frame

        let x =
            max(
                0,
                (documentFrame.width
                 - bounds.width) / 2
            )

        let y =
            max(
                0,
                (documentFrame.height
                 - bounds.height) / 2
            )

        contentView.scroll(
            to:
                NSPoint(
                    x: x,
                    y: y
                )
        )

        reflectScrolledClipView(
            contentView
        )

        didInitialPosition =
            true

        NSLog(
            "[Baram Motion] Preview initial position: %.0f, %.0f",
            x,
            y
        )
    }
}

// MARK: - Preview Canvas
