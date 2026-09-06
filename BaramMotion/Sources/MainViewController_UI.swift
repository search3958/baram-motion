import AppKit
import SwiftUI
import Combine

extension MainViewController {

    // MARK: - Layout

    func layoutUI() {

        let bounds = view.bounds

        guard bounds.width > 0,
              bounds.height > 0 else {

            NSLog(
                "[Baram Motion] WARNING: Invalid root bounds."
            )

            return
        }

        let width = bounds.width
        let height = bounds.height

        let timelineHeight = min(
            Layout.timelineHeight,
            max(100, height * 0.22)
        )

        timelinePanel.frame = NSRect(
            x: 0,
            y: 0,
            width: width,
            height: timelineHeight
        )

        let previewY = timelineHeight

        let previewHeight = max(
            0,
            height
                - timelineHeight
                - Layout.titlebarHeight
        )

        previewContainer.frame = NSRect(
            x: 0,
            y: previewY,
            width: width,
            height: previewHeight
        )

        previewScrollView.frame =
            previewContainer.bounds

        let panelWidth = min(
            Layout.floatingPanelWidth,
            max(
                Layout.floatingPanelMinimumWidth,
                width * 0.24
            )
        )

        let panelHeight = max(
            0,
            previewHeight
                - Layout.floatingPanelTopMargin
                - Layout.floatingPanelBottomMargin
        )

        let panelY =
            previewY
            + Layout.floatingPanelBottomMargin

        leftPanel.frame = NSRect(
            x: Layout.panelMargin,
            y: panelY,
            width: panelWidth,
            height: panelHeight
        )

        rightPanel.frame = NSRect(
            x: max(
                Layout.panelMargin,
                width
                    - Layout.panelMargin
                    - panelWidth
            ),
            y: panelY,
            width: panelWidth,
            height: panelHeight
        )
    }

    // MARK: - Toolbar

    func configureToolbarIfNeeded() {
        guard !toolbarConfigured else { return }
        guard let window = view.window else { NSLog("[Baram Motion] ERROR: Window unavailable for toolbar."); return }
        let toolbar = NSToolbar(identifier: NSToolbar.Identifier("BaramMotion.EditorToolbar"))
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        if #available(macOS 11.0, *) { toolbar.centeredItemIdentifier = nil }
        window.toolbar = toolbar
        if #available(macOS 11.0, *) { window.toolbarStyle = .unified }
        toolbarConfigured = true
        NSLog("[Baram Motion] Editor toolbar configured.")
    }

    // MARK: - Preview

    func createPreviewScrollView() -> PreviewScrollView {
        let scrollView = PreviewScrollView()
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .allowed
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.25
        scrollView.maxMagnification = 4.0

        let canvas = PreviewCanvasView()
        canvas.frame = NSRect(x: 0, y: 0, width: Layout.canvasWidth, height: Layout.canvasHeight)
        canvas.wantsLayer = true
        canvas.layer?.backgroundColor = BaramMotionTheme.canvasBackground.cgColor

        previewView = NSView()
        previewView.wantsLayer = true
        previewView.layer?.backgroundColor = BaramMotionTheme.previewBackground.cgColor
        previewView.layer?.cornerRadius = 2
        let previewX = (Layout.canvasWidth - Layout.previewWidth) / 2
        let previewY = (Layout.canvasHeight - Layout.previewHeight) / 2
        previewView.frame = NSRect(x: previewX, y: previewY, width: Layout.previewWidth, height: Layout.previewHeight)
        canvas.addSubview(previewView)

        previewResolutionLabel = NSTextField(labelWithString: "1920 × 1080")
        previewResolutionLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        previewResolutionLabel.textColor = NSColor.tertiaryLabelColor
        previewResolutionLabel.alignment = .right
        previewResolutionLabel.frame = NSRect(x: Layout.previewWidth - 170, y: 16, width: 150, height: 18)
        previewView.addSubview(previewResolutionLabel)

        canvas.previewView = previewView
        scrollView.documentView = canvas
        NSLog("[Baram Motion] Preview created: %.0f x %.0f", Layout.previewWidth, Layout.previewHeight)
        return scrollView
    }

    // MARK: - Timeline Panel

    func createTimelinePanel() -> NSView {
        let panel = NSView()
        panel.wantsLayer = true
        panel.layer?.backgroundColor = BaramMotionTheme.timelineBackground.cgColor

        let border = NSView()
        border.wantsLayer = true
        border.layer?.backgroundColor = BaramMotionTheme.separator.cgColor
        border.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(border)
        NSLayoutConstraint.activate([
            border.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            border.topAnchor.constraint(equalTo: panel.topAnchor),
            border.heightAnchor.constraint(equalToConstant: 1)
        ])

        timelineLayerPanel = TimelineLayerPanelView()
        timelineLayerPanel.translatesAutoresizingMaskIntoConstraints = false
        timelineLayerPanel.delegate = self
        panel.addSubview(timelineLayerPanel)

        let scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .allowed
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(scrollView)

        timelineContent = TimelineContentView()
        timelineContent.delegate = self
        timelineContent.frameRate = playbackFrameRate
        scrollView.documentView = timelineContent
        timelineScrollView = scrollView
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.contentView, queue: .main) { [weak self] _ in
            self?.syncTimelineLayerPanelScroll()
        }

        NSLayoutConstraint.activate([
            timelineLayerPanel.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            timelineLayerPanel.topAnchor.constraint(equalTo: border.bottomAnchor, constant: 4),
            timelineLayerPanel.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -4),
            timelineLayerPanel.widthAnchor.constraint(equalToConstant: Layout.timelineLayerPanelWidth),
            scrollView.leadingAnchor.constraint(equalTo: timelineLayerPanel.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: border.bottomAnchor, constant: 4),
            scrollView.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -4)
        ])

        updateTimelineSize()
        NSLog("[Baram Motion] Timeline initialized with fixed layer panel.")
        return panel
    }

    func syncTimelineLayerPanelScroll() {
        guard let clip = timelineScrollView?.contentView, let panel = timelineLayerPanel else {
            NSLog("[Baram Motion] ERROR: Timeline sync views unavailable.")
            return
        }
        panel.verticalOffset = clip.bounds.origin.y
        panel.documentHeight = timelineContent?.frame.height ?? 0
        panel.needsDisplay = true
    }

    // MARK: - Floating Panel

    func createFloatingPanel(title: String) -> (panel: NSView, content: NSView) {
        let panel = NSView()
        panel.wantsLayer = true
        panel.layer?.cornerRadius = Layout.glassRadius
        panel.layer?.shadowColor = NSColor.black.cgColor
        panel.layer?.shadowOpacity = 0.12
        panel.layer?.shadowOffset = CGSize(width: 0, height: -6)
        panel.layer?.shadowRadius = 24

        let contentView: NSView
        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            glassView.style = .regular
            glassView.cornerRadius = Layout.glassRadius
            glassView.frame = panel.bounds
            glassView.autoresizingMask = [.width, .height]
            glassView.tintColor = NSColor(white: 1, alpha: 0.035)
            panel.addSubview(glassView)
            contentView = NSView()
            contentView.translatesAutoresizingMaskIntoConstraints = false
            glassView.contentView = contentView
            NSLayoutConstraint.activate([
                contentView.leadingAnchor.constraint(equalTo: glassView.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: glassView.trailingAnchor),
                contentView.topAnchor.constraint(equalTo: glassView.topAnchor),
                contentView.bottomAnchor.constraint(equalTo: glassView.bottomAnchor)
            ])
        } else {
            let fallback = NSVisualEffectView()
            fallback.material = .hudWindow
            fallback.blendingMode = .withinWindow
            fallback.state = .active
            fallback.wantsLayer = true
            fallback.layer?.cornerRadius = Layout.glassRadius
            fallback.layer?.masksToBounds = true
            fallback.frame = panel.bounds
            fallback.autoresizingMask = [.width, .height]
            panel.addSubview(fallback)
            contentView = fallback
        }

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = BaramMotionTheme.primaryText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18)
        ])
        return (panel, contentView)
    }

    // MARK: - Legacy Layer List

    // Layer list was moved to the fixed timeline layer panel.
    func createLeftPanelContent() { }
    func refreshLayerList() { }
}

extension MainViewController: NSToolbarDelegate {
    enum ToolbarItemID {
        static let undo = NSToolbarItem.Identifier("BaramMotion.Undo")
        static let redo = NSToolbarItem.Identifier("BaramMotion.Redo")
        static let text = NSToolbarItem.Identifier("BaramMotion.Text")
        static let rectangle = NSToolbarItem.Identifier("BaramMotion.Rectangle")
        static let toggle = NSToolbarItem.Identifier("BaramMotion.Toggle")
        static let export = NSToolbarItem.Identifier("BaramMotion.Export")
        static let mp4 = NSToolbarItem.Identifier("BaramMotion.MP4Export")
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [ToolbarItemID.undo, ToolbarItemID.redo, .flexibleSpace, ToolbarItemID.text, ToolbarItemID.rectangle, ToolbarItemID.toggle, .flexibleSpace, ToolbarItemID.export, ToolbarItemID.mp4]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [ToolbarItemID.undo, ToolbarItemID.redo, .flexibleSpace, ToolbarItemID.text, ToolbarItemID.rectangle, ToolbarItemID.toggle, .flexibleSpace, ToolbarItemID.export, ToolbarItemID.mp4]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.target = self
        switch itemIdentifier {
        case ToolbarItemID.undo:
            item.label = "元に戻す"; item.toolTip = "元に戻す"; item.image = NSImage(systemSymbolName:"arrow.uturn.backward",accessibilityDescription:nil); item.action=#selector(undoAction)
        case ToolbarItemID.redo:
            item.label = "やり直す"; item.toolTip = "やり直す"; item.image = NSImage(systemSymbolName:"arrow.uturn.forward",accessibilityDescription:nil); item.action=#selector(redoAction)
        case ToolbarItemID.text:
            item.label = "テキスト"; item.toolTip = "テキストを追加"; item.image = NSImage(systemSymbolName:"textformat",accessibilityDescription:nil); item.action=#selector(addTextLayer)
        case ToolbarItemID.rectangle:
            item.label = "図形"; item.toolTip = "四角形を追加"; item.image = NSImage(systemSymbolName:"rectangle",accessibilityDescription:nil); item.action=#selector(addRectangleLayer)
        case ToolbarItemID.toggle:
            item.label = "Switch"; item.toolTip = "SwiftUI Switchを追加"; item.image = NSImage(systemSymbolName:"switch.2",accessibilityDescription:nil); item.action=#selector(addToggleLayer)
        case ToolbarItemID.export:
            item.label = "書き出し"; item.toolTip = "現在のフレームを書き出す"; item.image = NSImage(systemSymbolName:"square.and.arrow.down",accessibilityDescription:nil); item.action=#selector(exportCurrentFrame)
        case ToolbarItemID.mp4:
            item.label = "MP4"; item.toolTip = "タイムラインをH.264 MP4で書き出す"; item.image = NSImage(systemSymbolName:"film",accessibilityDescription:nil); item.action=#selector(exportMP4)
        default: return nil
        }
        return item
    }
}
