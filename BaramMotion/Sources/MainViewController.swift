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
    var timelineLayerPanel: TimelineLayerPanelView!

    var leftContentView: NSView!
    var rightContentView: NSView!
    var keyframeGraphView: KeyframeGraphView!
    var selectedGraphProperty: AnimatedProperty?
    var selectedGraphFrame: Int?

    var textContentField: NSTextField?
    var switchStateHostingView: NSHostingView<PanelSwitchEditorView>?
    var keyframeButtons: [AnimatedProperty: NSButton] = [:]

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
    var cornerRadiusField: NSTextField?
    var fontSizeField: NSTextField?
    var fontPopup: NSPopUpButton?
    var scaleXField: NSTextField?
    var scaleYField: NSTextField?
    var rotationField: NSTextField?
    var baseScaleXField: NSTextField?
    var baseScaleYField: NSTextField?
    var baseRotationField: NSTextField?
    var opacityField: NSTextField?
    var borderWidthField: NSTextField?
    var switchWidthField: NSTextField?
    var switchHeightField: NSTextField?

    // Playback controls
    let playbackFrameRate: CGFloat = 30
    lazy var playbackController: PlaybackController = PlaybackController(frameRate: Double(playbackFrameRate))
    var playbackHostingView: NSHostingView<PlaybackControlsView>?
    var playbackLastFrameCount: Int = 1
    var timelinePixelsPerSecond: CGFloat = 90
    var selectedDurationField: NSTextField?

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

    var timelineOrderBeforeSnapshot:
        [UUID: LayerSnapshot] = [:]

    // MARK: - Lifecycle

    override func loadView() {

        let rootView = MainEditorRootView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: 1400,
                height: 900
            )
        )
        rootView.onSpacePressed = { [weak self] in
            guard let self else { return }
            self.playbackController.togglePlay()
            self.refreshPlaybackUI()
            NSLog("[Baram Motion] Space: playback %@", self.playbackController.isPlaying ? "started" : "stopped")
        }
        rootView.onUndoPressed = { [weak self] in
            self?.undoAction()
        }
        rootView.onRedoPressed = { [weak self] in
            self?.redoAction()
        }
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
        view.window?.makeFirstResponder(view)
        refreshAll()
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        layoutUI()
    }

    // MARK: - Setup

    func setupUI() {

        playbackController.onFrameAdvanced = { [weak self] frame in
            guard let self else { return }
            DispatchQueue.main.async { self.playbackFrameChanged(frame) }
        }

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
                title: "グラフ エディタ"
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

        createKeyframePanelContent()
        createRightPanelContent()

        NSLog(
            "[Baram Motion] UI setup completed."
        )
    }

}
