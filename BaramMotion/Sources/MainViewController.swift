import AppKit
import SwiftUI
import Combine

// MARK: - Main View Controller

final class MainViewController: NSViewController {

    // MARK: - Views

    var previewScrollView: PreviewScrollView!
    var previewContainer: NSView!
    var previewView: NSView!
    var previewResolutionLabel: NSTextField!

    var timelinePanel: NSView!
    var timelineScrollView: NSScrollView!
    var timelineContent: TimelineContentView!

    var leftPanel: NSView!
    var rightPanel: NSView!

    var leftContentView: NSView!
    var rightContentView: NSView!

    var layerListScrollView: NSScrollView!
    var layerListStack: NSStackView!

    var inspectorScrollView: NSScrollView!
    var inspectorStack: NSStackView!

    // Inspector controls
    var colorWell: NSColorWell?
    var anchorPopup: NSPopUpButton?

    var xField: NSTextField?
    var yField: NSTextField?
    var widthField: NSTextField?
    var heightField: NSTextField?
    var fontSizeField: NSTextField?

    // Playback controls
    let playbackController = PlaybackController()
    var playbackHostingView: NSHostingView<PlaybackControlsView>?
    let playbackFrameRate: CGFloat = 30
    var playbackLastFrameCount: Int = 1

    // Preview position editing
    var previewEditBeforeSnapshot: [UUID: LayerSnapshot] = [:]
    var previewEditingLayerID: UUID?

    // MARK: - State

    var layers: [LayerModel] = []
    var selectedLayerID: UUID?

    var previewElementViews: [UUID: PreviewElementView] = [:]

    var toolbarConfigured = false

    var isRestoringUndoState = false

    var timelineEditBeforeSnapshot:
        [UUID: LayerSnapshot] = [:]

    // MARK: - Lifecycle

    override func loadView() {

        let rootView = NSView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: 1400,
                height: 900
            )
        )

        rootView.wantsLayer = true

        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        configureToolbarIfNeeded()
        refreshAll()
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        layoutUI()
    }

    // MARK: - Setup

    func setupUI() {

        view.wantsLayer = true

        view.layer?.backgroundColor =
            BaramMotionTheme.windowBackground.cgColor

        // Preview
        previewContainer = NSView()
        previewContainer.wantsLayer = true

        previewContainer.layer?.backgroundColor =
            BaramMotionTheme.pageBackground.cgColor

        previewScrollView =
            createPreviewScrollView()

        previewContainer.addSubview(
            previewScrollView
        )

        view.addSubview(
            previewContainer
        )

        // Timeline
        timelinePanel =
            createTimelinePanel()

        view.addSubview(
            timelinePanel
        )

        // Floating panels
        let left =
            createFloatingPanel(
                title: "パネル 1"
            )

        leftPanel = left.panel
        leftContentView = left.content

        let right =
            createFloatingPanel(
                title: "パネル 2"
            )

        rightPanel = right.panel
        rightContentView = right.content

        view.addSubview(leftPanel)
        view.addSubview(rightPanel)

        createLeftPanelContent()
        createRightPanelContent()

        NSLog(
            "[Baram Motion] UI setup completed."
        )
    }

}
