import AppKit

final class MainViewController: NSViewController {

// MARK: - Views

private var previewScrollView: PreviewScrollView!
private var previewContainer: NSView!

private var timelinePanel: NSView!
private var timelineScrollView: NSScrollView!

private var leftPanel: NSView!
private var rightPanel: NSView!

// MARK: - Constants

private enum Layout {

    static let panelMargin: CGFloat = 24

    static let timelineHeight: CGFloat = 110

    static let floatingPanelWidth: CGFloat = 300
    static let floatingPanelMinimumWidth: CGFloat = 220

    static let floatingPanelTopMargin: CGFloat = 24
    static let floatingPanelBottomMargin: CGFloat = 24

    static let glassRadius: CGFloat = 18

    // Preview
    static let previewWidth: CGFloat = 1920
    static let previewHeight: CGFloat = 1080

    // 大きな編集キャンバス
    // これによって縮小時でも自由にスクロールできる
    static let canvasWidth: CGFloat = 8000
    static let canvasHeight: CGFloat = 5000

    // Timeline
    static let timelineContentWidth: CGFloat = 3200
}

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

    self.view = rootView
}

override func viewDidLoad() {
    super.viewDidLoad()

    setupUI()
}

override func viewDidLayout() {
    super.viewDidLayout()

    layoutUI()
}

// MARK: - Setup

private func setupUI() {

    view.wantsLayer = true

    // アプリ全体の背景は明るいまま
    view.layer?.backgroundColor = NSColor(
        calibratedWhite: 0.94,
        alpha: 1.0
    ).cgColor

    // ---------------------------------------------------------
    // Preview
    // ---------------------------------------------------------

    previewContainer = NSView()

    previewContainer.wantsLayer = true

    // Preview周辺の背景
    previewContainer.layer?.backgroundColor = NSColor(
        calibratedWhite: 0.94,
        alpha: 1.0
    ).cgColor

    previewScrollView = createPreviewScrollView()

    previewContainer.addSubview(
        previewScrollView
    )

    view.addSubview(
        previewContainer
    )

    // ---------------------------------------------------------
    // Timeline
    // ---------------------------------------------------------

    timelinePanel = createTimelinePanel()

    view.addSubview(
        timelinePanel
    )

    // ---------------------------------------------------------
    // Floating panels
    // ---------------------------------------------------------

    leftPanel = createFloatingPanel(
        title: "パネル 1"
    )

    rightPanel = createFloatingPanel(
        title: "パネル 2"
    )

    view.addSubview(leftPanel)
    view.addSubview(rightPanel)

    NSLog(
        "[Baram Motion] UI setup completed."
    )
}

// MARK: - Layout

private func layoutUI() {

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

    // ---------------------------------------------------------
    // Timeline
    // ---------------------------------------------------------

    let timelineHeight = min(
        Layout.timelineHeight,
        max(80, height * 0.18)
    )

    timelinePanel.frame = NSRect(
        x: 0,
        y: 0,
        width: width,
        height: timelineHeight
    )

    // ---------------------------------------------------------
    // Preview area
    // ---------------------------------------------------------

    let previewY = timelineHeight

    let previewHeight = max(
        0,
        height - timelineHeight
    )

    previewContainer.frame = NSRect(
        x: 0,
        y: previewY,
        width: width,
        height: previewHeight
    )

    previewScrollView.frame =
        previewContainer.bounds

    // ---------------------------------------------------------
    // Floating panels
    //
    // 表示可能な範囲いっぱいまで縦に使う
    // ---------------------------------------------------------

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
        previewY + Layout.floatingPanelBottomMargin

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

    NSLog(
        "[Baram Motion] Layout updated: %.0f x %.0f | panel height %.0f",
        width,
        height,
        panelHeight
    )
}

// MARK: - Preview

private func createPreviewScrollView() -> PreviewScrollView {

    let scrollView = PreviewScrollView()

    scrollView.drawsBackground = false

    // Previewは上下左右自由に移動できる
    scrollView.hasHorizontalScroller = true
    scrollView.hasVerticalScroller = true

    scrollView.autohidesScrollers = true

    scrollView.horizontalScrollElasticity = .allowed
    scrollView.verticalScrollElasticity = .allowed

    // ズーム
    scrollView.allowsMagnification = true
    scrollView.minMagnification = 0.25
    scrollView.maxMagnification = 4.0

    // ---------------------------------------------------------
    // Large Editing Canvas
    // ---------------------------------------------------------

    let canvas = PreviewCanvasView()

    canvas.frame = NSRect(
        x: 0,
        y: 0,
        width: Layout.canvasWidth,
        height: Layout.canvasHeight
    )

    canvas.wantsLayer = true

    canvas.layer?.backgroundColor = NSColor(
        calibratedWhite: 0.94,
        alpha: 1.0
    ).cgColor

    // ---------------------------------------------------------
    // 1920 × 1080 Preview
    // ---------------------------------------------------------

    let preview = NSView()

    preview.wantsLayer = true

    // 黒いのはここだけ
    preview.layer?.backgroundColor = NSColor(
        calibratedWhite: 0.06,
        alpha: 1.0
    ).cgColor

    preview.layer?.cornerRadius = 2

    let previewX =
        (Layout.canvasWidth - Layout.previewWidth) / 2

    let previewY =
        (Layout.canvasHeight - Layout.previewHeight) / 2

    preview.frame = NSRect(
        x: previewX,
        y: previewY,
        width: Layout.previewWidth,
        height: Layout.previewHeight
    )

    canvas.addSubview(preview)

    // ---------------------------------------------------------
    // Preview text
    // ---------------------------------------------------------

    let previewLabel = NSTextField(
        labelWithString: "Preview"
    )

    previewLabel.font = NSFont.systemFont(
        ofSize: 48,
        weight: .light
    )

    previewLabel.textColor = NSColor(
        calibratedWhite: 0.4,
        alpha: 1.0
    )

    previewLabel.alignment = .center

    previewLabel.frame = NSRect(
        x: 0,
        y: (Layout.previewHeight - 58) / 2,
        width: Layout.previewWidth,
        height: 58
    )

    preview.addSubview(
        previewLabel
    )

    // ---------------------------------------------------------
    // Resolution
    // ---------------------------------------------------------

    let resolutionLabel = NSTextField(
        labelWithString: "1920 × 1080"
    )

    resolutionLabel.font =
        NSFont.monospacedSystemFont(
            ofSize: 14,
            weight: .regular
        )

    resolutionLabel.textColor =
        NSColor(
            calibratedWhite: 0.35,
            alpha: 1.0
        )

    resolutionLabel.alignment = .right

    resolutionLabel.frame = NSRect(
        x: Layout.previewWidth - 160,
        y: 16,
        width: 140,
        height: 18
    )

    preview.addSubview(
        resolutionLabel
    )

    canvas.previewView = preview

    scrollView.documentView = canvas

    NSLog(
        "[Baram Motion] Preview canvas created: %.0f x %.0f",
        Layout.canvasWidth,
        Layout.canvasHeight
    )

    NSLog(
        "[Baram Motion] Preview created: %.0f x %.0f",
        Layout.previewWidth,
        Layout.previewHeight
    )

    return scrollView
}

// MARK: - Timeline

private func createTimelinePanel() -> NSView {

    let panel = NSView()

    panel.wantsLayer = true

    panel.layer?.backgroundColor = NSColor(
        calibratedWhite: 0.91,
        alpha: 1.0
    ).cgColor

    // ---------------------------------------------------------
    // Border
    // ---------------------------------------------------------

    let border = NSView()

    border.wantsLayer = true

    border.layer?.backgroundColor = NSColor(
        calibratedWhite: 0.80,
        alpha: 1.0
    ).cgColor

    border.translatesAutoresizingMaskIntoConstraints = false

    panel.addSubview(border)

    NSLayoutConstraint.activate([
        border.leadingAnchor.constraint(
            equalTo: panel.leadingAnchor
        ),
        border.trailingAnchor.constraint(
            equalTo: panel.trailingAnchor
        ),
        border.topAnchor.constraint(
            equalTo: panel.topAnchor
        ),
        border.heightAnchor.constraint(
            equalToConstant: 1
        )
    ])

    // ---------------------------------------------------------
    // Horizontal Scroll View
    // ---------------------------------------------------------

    let scrollView = NSScrollView()

    scrollView.hasHorizontalScroller = true
    scrollView.hasVerticalScroller = false
    scrollView.autohidesScrollers = true

    scrollView.horizontalScrollElasticity = .allowed
    scrollView.verticalScrollElasticity = .none

    scrollView.drawsBackground = false

    scrollView.translatesAutoresizingMaskIntoConstraints = false

    panel.addSubview(scrollView)

    NSLayoutConstraint.activate([
        scrollView.leadingAnchor.constraint(
            equalTo: panel.leadingAnchor
        ),
        scrollView.trailingAnchor.constraint(
            equalTo: panel.trailingAnchor
        ),
        scrollView.topAnchor.constraint(
            equalTo: border.bottomAnchor,
            constant: 8
        ),
        scrollView.bottomAnchor.constraint(
            equalTo: panel.bottomAnchor,
            constant: -8
        )
    ])

    // ---------------------------------------------------------
    // Timeline Content
    // ---------------------------------------------------------

    let timelineContent = TimelineContentView()

    timelineContent.frame = NSRect(
        x: 0,
        y: 0,
        width: Layout.timelineContentWidth,
        height: Layout.timelineHeight - 16
    )

    scrollView.documentView = timelineContent

    timelineScrollView = scrollView

    NSLog(
        "[Baram Motion] Timeline horizontal scrolling enabled."
    )

    return panel
}

// MARK: - Liquid Glass

private func createFloatingPanel(
    title: String
) -> NSView {

    let panel = NSView()

    panel.wantsLayer = true

    panel.layer?.cornerRadius =
        Layout.glassRadius

    panel.layer?.shadowColor =
        NSColor.black.cgColor

    panel.layer?.shadowOpacity = 0.12

    panel.layer?.shadowOffset =
        CGSize(
            width: 0,
            height: -6
        )

    panel.layer?.shadowRadius = 24

    // ---------------------------------------------------------
    // macOS 26
    // ---------------------------------------------------------

    if #available(macOS 26.0, *) {

        let glassView =
            NSGlassEffectView()

        glassView.style = .regular

        glassView.cornerRadius =
            Layout.glassRadius

        glassView.autoresizingMask = [
            .width,
            .height
        ]

        glassView.frame =
            panel.bounds

        glassView.tintColor =
            NSColor(
                white: 1.0,
                alpha: 0.035
            )

        panel.addSubview(
            glassView
        )

        let contentView = NSView()

        contentView.translatesAutoresizingMaskIntoConstraints =
            false

        glassView.contentView =
            contentView

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(
                equalTo: glassView.leadingAnchor
            ),
            contentView.trailingAnchor.constraint(
                equalTo: glassView.trailingAnchor
            ),
            contentView.topAnchor.constraint(
                equalTo: glassView.topAnchor
            ),
            contentView.bottomAnchor.constraint(
                equalTo: glassView.bottomAnchor
            )
        ])

        createPanelContent(
            title: title,
            container: contentView
        )

        NSLog(
            "[Baram Motion] macOS 26 Liquid Glass panel created: %@",
            title
        )

    } else {

        let fallback =
            NSVisualEffectView()

        fallback.material = .hudWindow
        fallback.blendingMode = .withinWindow
        fallback.state = .active

        fallback.wantsLayer = true

        fallback.layer?.cornerRadius =
            Layout.glassRadius

        fallback.layer?.masksToBounds =
            true

        fallback.autoresizingMask = [
            .width,
            .height
        ]

        fallback.frame =
            panel.bounds

        panel.addSubview(
            fallback
        )

        createPanelContent(
            title: title,
            container: fallback
        )

        NSLog(
            "[Baram Motion] Fallback glass panel created: %@",
            title
        )
    }

    return panel
}

// MARK: - Panel Content

private func createPanelContent(
    title: String,
    container: NSView
) {

    let titleLabel =
        NSTextField(
            labelWithString: title
        )

    titleLabel.font =
        NSFont.systemFont(
            ofSize: 13,
            weight: .semibold
        )

    titleLabel.textColor =
        NSColor(
            calibratedWhite: 0.18,
            alpha: 1.0
        )

    titleLabel.translatesAutoresizingMaskIntoConstraints =
        false

    container.addSubview(
        titleLabel
    )

    NSLayoutConstraint.activate([
        titleLabel.leadingAnchor.constraint(
            equalTo: container.leadingAnchor,
            constant: 20
        ),
        titleLabel.trailingAnchor.constraint(
            lessThanOrEqualTo: container.trailingAnchor,
            constant: -20
        ),
        titleLabel.topAnchor.constraint(
            equalTo: container.topAnchor,
            constant: 18
        )
    ])
}


}

// MARK: - Preview Scroll View

final class PreviewScrollView: NSScrollView {


private var didInitialPosition = false

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

    let bounds = contentView.bounds

    guard bounds.width > 0,
          bounds.height > 0 else {
        return
    }

    let documentFrame = documentView.frame

    let x = max(
        0,
        (documentFrame.width - bounds.width) / 2
    )

    let y = max(
        0,
        (documentFrame.height - bounds.height) / 2
    )

    contentView.scroll(
        to: NSPoint(
            x: x,
            y: y
        )
    )

    reflectScrolledClipView(
        contentView
    )

    didInitialPosition = true

    NSLog(
        "[Baram Motion] Preview canvas initial position: %.0f, %.0f",
        x,
        y
    )
}


}

// MARK: - Preview Canvas

final class PreviewCanvasView: NSView {


weak var previewView: NSView?


}

// MARK: - Timeline

final class TimelineContentView: NSView {


override func draw(_ dirtyRect: NSRect) {

    super.draw(dirtyRect)

    guard let context =
            NSGraphicsContext.current?.cgContext else {

        NSLog(
            "[Baram Motion] ERROR: Timeline graphics context is nil."
        )

        return
    }

    NSColor(
        calibratedWhite: 0.88,
        alpha: 1.0
    ).setFill()

    dirtyRect.fill()

    let baselineY: CGFloat = 40
    let interval: CGFloat = 100

    NSColor(
        calibratedWhite: 0.65,
        alpha: 1.0
    ).setStroke()

    context.setLineWidth(1)

    context.move(
        to: CGPoint(
            x: 0,
            y: baselineY
        )
    )

    context.addLine(
        to: CGPoint(
            x: bounds.width,
            y: baselineY
        )
    )

    context.strokePath()

    var x: CGFloat = 0

    while x <= bounds.width {

        let major =
            Int(x / interval) % 5 == 0

        let markHeight: CGFloat =
            major ? 16 : 9

        context.move(
            to: CGPoint(
                x: x,
                y: baselineY
            )
        )

        context.addLine(
            to: CGPoint(
                x: x,
                y: baselineY + markHeight
            )
        )

        context.strokePath()

        x += interval
    }
}
}
