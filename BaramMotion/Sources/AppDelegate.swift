
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var window: NSWindow!

    private enum WindowConfig {
        static let initialWidth: CGFloat = 1400
        static let initialHeight: CGFloat = 900

        static let minimumWidth: CGFloat = 960
        static let minimumHeight: CGFloat = 640
    }

    func applicationDidFinishLaunching(_ notification: Notification) {

        let viewController = MainViewController()

        let initialFrame = NSRect(
            x: 0,
            y: 0,
            width: WindowConfig.initialWidth,
            height: WindowConfig.initialHeight
        )

        window = NSWindow(
            contentRect: initialFrame,
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        guard let window else {
            NSLog("[Baram Motion] ERROR: ウィンドウ生成に失敗しました。")
            return
        }

        window.title = "Baram Motion"

        window.minSize = NSSize(
            width: WindowConfig.minimumWidth,
            height: WindowConfig.minimumHeight
        )

        window.contentMinSize = NSSize(
            width: WindowConfig.minimumWidth,
            height: WindowConfig.minimumHeight
        )

        // ---------------------------------------------------------
        // macOS 26 window layout
        // ---------------------------------------------------------

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        // コンテンツをタイトルバー領域まで広げる
        window.styleMask.insert(.fullSizeContentView)

        window.isMovableByWindowBackground = true

        // ---------------------------------------------------------
        // Full Screen
        // ---------------------------------------------------------

        window.collectionBehavior.insert(.fullScreenPrimary)

        if let zoomButton = window.standardWindowButton(.zoomButton) {
            zoomButton.isEnabled = true
        }

        // ---------------------------------------------------------
        // Content
        // ---------------------------------------------------------

        window.contentViewController = viewController

        // ---------------------------------------------------------
        // Initial frame
        // ---------------------------------------------------------

        var safeFrame = initialFrame

        safeFrame.size.width = max(
            safeFrame.size.width,
            WindowConfig.minimumWidth
        )

        safeFrame.size.height = max(
            safeFrame.size.height,
            WindowConfig.minimumHeight
        )

        window.setFrame(
            safeFrame,
            display: true,
            animate: false
        )

        window.center()
        window.makeKeyAndOrderFront(nil)

        NSLog(
            "[Baram Motion] Window initialized: %.0f x %.0f",
            safeFrame.width,
            safeFrame.height
        )

        NSLog(
            "[Baram Motion] Minimum size: %.0f x %.0f",
            WindowConfig.minimumWidth,
            WindowConfig.minimumHeight
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {

        return true
    }
}