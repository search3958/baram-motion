import AppKit

// MARK: - Main View Controller

final class MainViewController: NSViewController {

    // MARK: - Layer Types

    enum LayerKind: String {
        case text
        case rectangle
        case toggle

        var displayName: String {
            switch self {
            case .text:
                return "Text"
            case .rectangle:
                return "Rectangle"
            case .toggle:
                return "Switch"
            }
        }
    }

    enum PositionAnchor: Int {
        case topLeft = 0
        case center = 1

        var displayName: String {
            switch self {
            case .topLeft:
                return "左上から"
            case .center:
                return "中央から"
            }
        }
    }

    // MARK: - Theme

    enum BaramMotionTheme {

        // Window / panels
        static let windowBackground =
            NSColor.windowBackgroundColor

        static let pageBackground =
            NSColor.underPageBackgroundColor

        static let controlBackground =
            NSColor.controlBackgroundColor

        static let separator =
            NSColor.separatorColor

        // Text
        static let primaryText =
            NSColor.labelColor

        static let secondaryText =
            NSColor.secondaryLabelColor

        static let tertiaryText =
            NSColor.tertiaryLabelColor

        // Accent
        static let accent =
            NSColor.controlAccentColor

        static let selectedBackground =
            NSColor.selectedContentBackgroundColor

        // Editor canvas
        static let canvasBackground =
            NSColor.controlBackgroundColor

        static let timelineBackground =
            NSColor.controlBackgroundColor

        static let timelineAlternateBackground =
            NSColor.underPageBackgroundColor

        // Preview itself is intentionally black.
        static let previewBackground =
            NSColor.black
    }

    // MARK: - Layer Model

    final class LayerModel {

        let id: UUID

        var kind: LayerKind
        var name: String

        var color: NSColor

        // Position in 1920x1080 Preview coordinates.
        // Origin is interpreted according to anchor.
        var x: CGFloat
        var y: CGFloat

        var width: CGFloat
        var height: CGFloat

        var fontSize: CGFloat

        var anchor: PositionAnchor

        // Timeline
        var startTime: CGFloat
        var duration: CGFloat

        // Switch only
        var isOn: Bool

        init(
            id: UUID = UUID(),
            kind: LayerKind,
            name: String,
            color: NSColor,
            x: CGFloat,
            y: CGFloat,
            width: CGFloat,
            height: CGFloat,
            fontSize: CGFloat = 56,
            anchor: PositionAnchor = .topLeft,
            startTime: CGFloat = 0,
            duration: CGFloat = 5,
            isOn: Bool = true
        ) {
            self.id = id
            self.kind = kind
            self.name = name
            self.color = color
            self.x = x
            self.y = y
            self.width = width
            self.height = height
            self.fontSize = fontSize
            self.anchor = anchor
            self.startTime = startTime
            self.duration = duration
            self.isOn = isOn
        }

        func copyLayer() -> LayerModel {
            return LayerModel(
                id: id,
                kind: kind,
                name: name,
                color: color,
                x: x,
                y: y,
                width: width,
                height: height,
                fontSize: fontSize,
                anchor: anchor,
                startTime: startTime,
                duration: duration,
                isOn: isOn
            )
        }
    }

    struct LayerSnapshot {
        let layer: LayerModel
    }

    struct LayerModelProxy {
        let id: UUID
        let kindDisplayName: String
        let name: String
        let color: NSColor
        let startTime: CGFloat
        let duration: CGFloat
    }

    // MARK: - Layout

    enum Layout {

        static let panelMargin: CGFloat = 24

        static let titlebarHeight: CGFloat = 56

        static let timelineHeight: CGFloat = 170

        static let floatingPanelWidth: CGFloat = 300
        static let floatingPanelMinimumWidth: CGFloat = 220

        static let floatingPanelTopMargin: CGFloat = 24
        static let floatingPanelBottomMargin: CGFloat = 24

        static let glassRadius: CGFloat = 18

        // Preview
        static let previewWidth: CGFloat = 1920
        static let previewHeight: CGFloat = 1080

        // Large editor canvas
        static let canvasWidth: CGFloat = 8000
        static let canvasHeight: CGFloat = 5000

        // Timeline
        static let timelineScale: CGFloat = 90
        static let minimumTimelineWidth: CGFloat = 3200
    }

    // MARK: - Views

    private var previewScrollView: PreviewScrollView!
    private var previewContainer: NSView!
    private var previewView: NSView!
    private var previewResolutionLabel: NSTextField!

    private var timelinePanel: NSView!
    private var timelineScrollView: NSScrollView!
    private var timelineContent: TimelineContentView!

    private var leftPanel: NSView!
    private var rightPanel: NSView!

    private var leftContentView: NSView!
    private var rightContentView: NSView!

    private var layerListScrollView: NSScrollView!
    private var layerListStack: NSStackView!

    private var inspectorScrollView: NSScrollView!
    private var inspectorStack: NSStackView!

    // Inspector controls
    private var colorWell: NSColorWell?
    private var anchorPopup: NSPopUpButton?

    private var xField: NSTextField?
    private var yField: NSTextField?
    private var widthField: NSTextField?
    private var heightField: NSTextField?
    private var fontSizeField: NSTextField?

    private var switchStateControl: NSSwitchControl?

    // MARK: - State

    private var layers: [LayerModel] = []
    private var selectedLayerID: UUID?

    private var previewElementViews: [UUID: PreviewElementView] = [:]

    private var toolbarConfigured = false

    private var isRestoringUndoState = false

    private var timelineEditBeforeSnapshot:
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

    private func setupUI() {

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

    private func configureToolbarIfNeeded() {

        guard !toolbarConfigured else {
            return
        }

        guard let window = view.window else {

            NSLog(
                "[Baram Motion] ERROR: Window unavailable for toolbar."
            )

            return
        }

        let toolbar =
            NSToolbar(
                identifier:
                    NSToolbar.Identifier(
                        "BaramMotion.EditorToolbar"
                    )
            )

        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false

        if #available(macOS 11.0, *) {
            toolbar.centeredItemIdentifier = nil
        }

        window.toolbar = toolbar

        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unified
        }

        toolbarConfigured = true

        NSLog(
            "[Baram Motion] Editor toolbar configured."
        )
    }

    // MARK: - Preview

    private func createPreviewScrollView()
        -> PreviewScrollView {

        let scrollView =
            PreviewScrollView()

        scrollView.drawsBackground = false

        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        scrollView.horizontalScrollElasticity =
            .allowed

        scrollView.verticalScrollElasticity =
            .allowed

        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.25
        scrollView.maxMagnification = 4.0

        let canvas =
            PreviewCanvasView()

        canvas.frame = NSRect(
            x: 0,
            y: 0,
            width: Layout.canvasWidth,
            height: Layout.canvasHeight
        )

        canvas.wantsLayer = true

        canvas.layer?.backgroundColor =
            BaramMotionTheme.canvasBackground.cgColor

        previewView = NSView()

        previewView.wantsLayer = true

        // Preview itself is intentionally black.
        previewView.layer?.backgroundColor =
            BaramMotionTheme.previewBackground.cgColor

        previewView.layer?.cornerRadius = 2

        let previewX =
            (Layout.canvasWidth
             - Layout.previewWidth) / 2

        let previewY =
            (Layout.canvasHeight
             - Layout.previewHeight) / 2

        previewView.frame = NSRect(
            x: previewX,
            y: previewY,
            width: Layout.previewWidth,
            height: Layout.previewHeight
        )

        canvas.addSubview(previewView)

        let previewLabel =
            NSTextField(
                labelWithString: "Preview"
            )

        previewLabel.font =
            NSFont.systemFont(
                ofSize: 48,
                weight: .light
            )

        previewLabel.textColor =
            NSColor.secondaryLabelColor

        previewLabel.alignment = .center

        previewLabel.frame = NSRect(
            x: 0,
            y: (Layout.previewHeight - 58) / 2,
            width: Layout.previewWidth,
            height: 58
        )

        previewView.addSubview(
            previewLabel
        )

        previewResolutionLabel =
            NSTextField(
                labelWithString:
                    "1920 × 1080"
            )

        previewResolutionLabel.font =
            NSFont.monospacedSystemFont(
                ofSize: 13,
                weight: .regular
            )

        previewResolutionLabel.textColor =
            NSColor.tertiaryLabelColor

        previewResolutionLabel.alignment =
            .right

        previewResolutionLabel.frame = NSRect(
            x: Layout.previewWidth - 170,
            y: 16,
            width: 150,
            height: 18
        )

        previewView.addSubview(
            previewResolutionLabel
        )

        canvas.previewView =
            previewView

        scrollView.documentView =
            canvas

        NSLog(
            "[Baram Motion] Preview created: %.0f x %.0f",
            Layout.previewWidth,
            Layout.previewHeight
        )

        return scrollView
    }

    // MARK: - Timeline Panel

    private func createTimelinePanel()
        -> NSView {

        let panel = NSView()

        panel.wantsLayer = true

        panel.layer?.backgroundColor =
            BaramMotionTheme.timelineBackground.cgColor

        let border = NSView()

        border.wantsLayer = true

        border.layer?.backgroundColor =
            BaramMotionTheme.separator.cgColor

        border.translatesAutoresizingMaskIntoConstraints =
            false

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

        let scrollView =
            NSScrollView()

        scrollView.hasHorizontalScroller =
            true

        scrollView.hasVerticalScroller =
            true

        scrollView.autohidesScrollers =
            true

        scrollView.horizontalScrollElasticity =
            .allowed

        scrollView.verticalScrollElasticity =
            .allowed

        scrollView.drawsBackground = false

        scrollView.translatesAutoresizingMaskIntoConstraints =
            false

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
                constant: 4
            ),
            scrollView.bottomAnchor.constraint(
                equalTo: panel.bottomAnchor,
                constant: -4
            )
        ])

        timelineContent =
            TimelineContentView()

        timelineContent.delegate = self

        scrollView.documentView =
            timelineContent

        timelineScrollView =
            scrollView

        updateTimelineSize()

        NSLog(
            "[Baram Motion] Timeline initialized."
        )

        return panel
    }

    // MARK: - Floating Panel

    private func createFloatingPanel(
        title: String
    ) -> (
        panel: NSView,
        content: NSView
    ) {

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

        let contentView: NSView

        if #available(macOS 26.0, *) {

            let glassView =
                NSGlassEffectView()

            glassView.style = .regular
            glassView.cornerRadius =
                Layout.glassRadius

            glassView.frame =
                panel.bounds

            glassView.autoresizingMask = [
                .width,
                .height
            ]

            glassView.tintColor =
                NSColor(
                    white: 1,
                    alpha: 0.035
                )

            panel.addSubview(
                glassView
            )

            contentView = NSView()

            contentView.translatesAutoresizingMaskIntoConstraints =
                false

            glassView.contentView =
                contentView

            NSLayoutConstraint.activate([
                contentView.leadingAnchor.constraint(
                    equalTo:
                        glassView.leadingAnchor
                ),
                contentView.trailingAnchor.constraint(
                    equalTo:
                        glassView.trailingAnchor
                ),
                contentView.topAnchor.constraint(
                    equalTo:
                        glassView.topAnchor
                ),
                contentView.bottomAnchor.constraint(
                    equalTo:
                        glassView.bottomAnchor
                )
            ])

        } else {

            let fallback =
                NSVisualEffectView()

            fallback.material =
                .hudWindow

            fallback.blendingMode =
                .withinWindow

            fallback.state =
                .active

            fallback.wantsLayer = true

            fallback.layer?.cornerRadius =
                Layout.glassRadius

            fallback.layer?.masksToBounds =
                true

            fallback.frame =
                panel.bounds

            fallback.autoresizingMask = [
                .width,
                .height
            ]

            panel.addSubview(
                fallback
            )

            contentView =
                fallback
        }

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
            BaramMotionTheme.primaryText

        titleLabel.translatesAutoresizingMaskIntoConstraints =
            false

        contentView.addSubview(
            titleLabel
        )

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(
                equalTo:
                    contentView.leadingAnchor,
                constant: 20
            ),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo:
                    contentView.trailingAnchor,
                constant: -20
            ),
            titleLabel.topAnchor.constraint(
                equalTo:
                    contentView.topAnchor,
                constant: 18
            )
        ])

        return (
            panel: panel,
            content: contentView
        )
    }

    // MARK: - Left Panel

    private func createLeftPanelContent() {

        let scrollView =
            NSScrollView()

        scrollView.hasVerticalScroller =
            true

        scrollView.drawsBackground =
            false

        scrollView.borderType =
            .noBorder

        scrollView.translatesAutoresizingMaskIntoConstraints =
            false

        layerListStack =
            NSStackView()

        layerListStack.orientation =
            .vertical

        layerListStack.alignment =
            .width

        layerListStack.spacing =
            6

        layerListStack.translatesAutoresizingMaskIntoConstraints =
            false

        scrollView.documentView =
            layerListStack

        leftContentView.addSubview(
            scrollView
        )

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(
                equalTo:
                    leftContentView.leadingAnchor,
                constant: 12
            ),
            scrollView.trailingAnchor.constraint(
                equalTo:
                    leftContentView.trailingAnchor,
                constant: -12
            ),
            scrollView.topAnchor.constraint(
                equalTo:
                    leftContentView.topAnchor,
                constant: 54
            ),
            scrollView.bottomAnchor.constraint(
                equalTo:
                    leftContentView.bottomAnchor,
                constant: -12
            ),
            layerListStack.widthAnchor.constraint(
                equalTo:
                    scrollView.contentView.widthAnchor
            )
        ])

        layerListScrollView =
            scrollView

        refreshLayerList()
    }

    private func refreshLayerList() {

        guard let stack = layerListStack else {

            NSLog(
                "[Baram Motion] ERROR: Layer list stack is nil."
            )

            return
        }

        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard !layers.isEmpty else {

            let emptyLabel =
                NSTextField(
                    labelWithString:
                        "レイヤーなし"
                )

            emptyLabel.alignment =
                .center

            emptyLabel.textColor =
                NSColor.secondaryLabelColor

            stack.addArrangedSubview(
                emptyLabel
            )

            return
        }

        for layer in layers {

            let button =
                LayerListButton()

            button.layerID =
                layer.id

            button.title =
                "\(layer.kind.displayName)  \(layer.name)"

            button.target =
                self

            button.action =
                #selector(
                    layerListButtonPressed(_:)
                )

            button.bezelStyle =
                .rounded

            button.controlSize =
                .small

            button.font =
                NSFont.systemFont(
                    ofSize: 12,
                    weight:
                        layer.id == selectedLayerID
                        ? .semibold
                        : .regular
                )

            if #available(macOS 10.14, *) {
                button.contentTintColor =
                    layer.id == selectedLayerID
                    ? NSColor.controlAccentColor
                    : NSColor.labelColor
            }

            stack.addArrangedSubview(
                button
            )
        }
    }

    @objc
    private func layerListButtonPressed(
        _ sender: LayerListButton
    ) {

        guard let id = sender.layerID else {

            NSLog(
                "[Baram Motion] ERROR: Layer button has no ID."
            )

            return
        }

        selectLayer(id)
    }

    // MARK: - Right Panel

    private func createRightPanelContent() {

        let scrollView =
            NSScrollView()

        scrollView.hasVerticalScroller =
            true

        scrollView.drawsBackground =
            false

        scrollView.borderType =
            .noBorder

        scrollView.translatesAutoresizingMaskIntoConstraints =
            false

        inspectorStack =
            NSStackView()

        inspectorStack.orientation =
            .vertical

        inspectorStack.alignment =
            .leading

        inspectorStack.spacing =
            10

        inspectorStack.translatesAutoresizingMaskIntoConstraints =
            false

        scrollView.documentView =
            inspectorStack

        rightContentView.addSubview(
            scrollView
        )

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(
                equalTo:
                    rightContentView.leadingAnchor,
                constant: 16
            ),
            scrollView.trailingAnchor.constraint(
                equalTo:
                    rightContentView.trailingAnchor,
                constant: -16
            ),
            scrollView.topAnchor.constraint(
                equalTo:
                    rightContentView.topAnchor,
                constant: 52
            ),
            scrollView.bottomAnchor.constraint(
                equalTo:
                    rightContentView.bottomAnchor,
                constant: -12
            ),
            inspectorStack.widthAnchor.constraint(
                equalTo:
                    scrollView.contentView.widthAnchor
            )
        ])

        inspectorScrollView =
            scrollView

        rebuildInspector()
    }

    private func rebuildInspector() {

        guard let stack = inspectorStack else {

            NSLog(
                "[Baram Motion] ERROR: Inspector stack is nil."
            )

            return
        }

        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        colorWell = nil
        anchorPopup = nil
        xField = nil
        yField = nil
        widthField = nil
        heightField = nil
        fontSizeField = nil
        switchStateControl = nil

        guard let layer = selectedLayer else {

            let empty =
                NSTextField(
                    labelWithString:
                        "レイヤーを選択してください"
                )

            empty.font =
                NSFont.systemFont(
                    ofSize: 12
                )

            empty.textColor =
                NSColor.secondaryLabelColor

            empty.alignment =
                .center

            empty.translatesAutoresizingMaskIntoConstraints =
                false

            stack.addArrangedSubview(
                empty
            )

            return
        }

        let typeLabel =
            NSTextField(
                labelWithString:
                    layer.kind.displayName
            )

        typeLabel.font =
            NSFont.systemFont(
                ofSize: 12,
                weight: .semibold
            )

        typeLabel.textColor =
            BaramMotionTheme.primaryText

        stack.addArrangedSubview(
            typeLabel
        )

        // Color
        let colorControl =
            NSColorWell()

        colorControl.color =
            layer.color

        colorControl.target =
            self

        colorControl.action =
            #selector(
                colorChanged(_:)
            )

        colorWell =
            colorControl

        stack.addArrangedSubview(
            makeInspectorRow(
                title: "カラー",
                control: colorControl
            )
        )

        // Anchor
        let anchorControl =
            NSPopUpButton()

        anchorControl.addItems(
            withTitles: [
                PositionAnchor
                    .topLeft
                    .displayName,

                PositionAnchor
                    .center
                    .displayName
            ]
        )

        anchorControl.selectItem(
            at: layer.anchor.rawValue
        )

        anchorControl.target =
            self

        anchorControl.action =
            #selector(
                anchorChanged(_:)
            )

        anchorPopup =
            anchorControl

        stack.addArrangedSubview(
            makeInspectorRow(
                title: "基準位置",
                control: anchorControl
            )
        )

        // X
        let positionX =
            makeNumericField(
                layer.x
            )

        positionX.target =
            self

        positionX.action =
            #selector(
                positionFieldChanged(_:)
            )

        xField =
            positionX

        stack.addArrangedSubview(
            makeInspectorRow(
                title: "X",
                control: positionX
            )
        )

        // Y
        let positionY =
            makeNumericField(
                layer.y
            )

        positionY.target =
            self

        positionY.action =
            #selector(
                positionFieldChanged(_:)
            )

        yField =
            positionY

        stack.addArrangedSubview(
            makeInspectorRow(
                title: "Y",
                control: positionY
            )
        )

        // Width
        let widthControl =
            makeNumericField(
                layer.width
            )

        widthControl.target =
            self

        widthControl.action =
            #selector(
                sizeFieldChanged(_:)
            )

        widthField =
            widthControl

        stack.addArrangedSubview(
            makeInspectorRow(
                title: "幅",
                control: widthControl
            )
        )

        // Height
        let heightControl =
            makeNumericField(
                layer.height
            )

        heightControl.target =
            self

        heightControl.action =
            #selector(
                sizeFieldChanged(_:)
            )

        heightField =
            heightControl

        stack.addArrangedSubview(
            makeInspectorRow(
                title: "高さ",
                control: heightControl
            )
        )

        // Text only
        if layer.kind == .text {

            let fontControl =
                makeNumericField(
                    layer.fontSize
                )

            fontControl.target =
                self

            fontControl.action =
                #selector(
                    fontSizeChanged(_:)
                )

            fontSizeField =
                fontControl

            stack.addArrangedSubview(
                makeInspectorRow(
                    title: "文字サイズ",
                    control: fontControl
                )
            )
        }

        // Switch only
        if layer.kind == .toggle {

            let switchControl =
                NSSwitchControl(
                    isOn: layer.isOn
                )

            switchControl.target =
                self

            switchControl.action =
                #selector(
                    switchStateChanged(_:)
                )

            switchStateControl =
                switchControl

            stack.addArrangedSubview(
                makeInspectorRow(
                    title: "状態",
                    control: switchControl
                )
            )
        }

        // Remove button
        let deleteButton =
            NSButton(
                title: "レイヤーを削除",
                target: self,
                action:
                    #selector(
                        deleteSelectedLayer
                    )
            )

        deleteButton.bezelStyle =
            .rounded

        deleteButton.controlSize =
            .small

        deleteButton.contentTintColor =
            NSColor.systemRed

        deleteButton.translatesAutoresizingMaskIntoConstraints =
            false

        stack.addArrangedSubview(
            NSView()
        )

        stack.addArrangedSubview(
            deleteButton
        )
    }

    private func makeInspectorRow(
        title: String,
        control: NSView
    ) -> NSView {

        let row =
            NSStackView()

        row.orientation =
            .horizontal

        row.alignment =
            .centerY

        row.spacing =
            8

        let label =
            NSTextField(
                labelWithString: title
            )

        label.font =
            NSFont.systemFont(
                ofSize: 11
            )

        label.textColor =
            NSColor.secondaryLabelColor

        label.widthAnchor.constraint(
            equalToConstant: 78
        ).isActive = true

        control.setContentHuggingPriority(
            .defaultLow,
            for: .horizontal
        )

        control.setContentCompressionResistancePriority(
            .defaultHigh,
            for: .horizontal
        )

        row.addArrangedSubview(
            label
        )

        row.addArrangedSubview(
            control
        )

        return row
    }

    private func makeNumericField(
        _ value: CGFloat
    ) -> NSTextField {

        let field =
            NSTextField(
                string:
                    formatNumber(value)
            )

        field.font =
            NSFont.monospacedSystemFont(
                ofSize: 11,
                weight: .regular
            )

        field.controlSize =
            .small

        field.alignment =
            .right

        field.widthAnchor.constraint(
            equalToConstant: 120
        ).isActive = true

        return field
    }

    // MARK: - Selected Layer

    private var selectedLayer: LayerModel? {

        guard let selectedLayerID else {
            return nil
        }

        return layers.first {
            $0.id == selectedLayerID
        }
    }

    private func selectLayer(
        _ id: UUID?
    ) {

        selectedLayerID =
            id

        refreshLayerList()
        refreshSelectionAppearance()
        rebuildInspector()

        timelineContent.reload(
            layers: timelineProxies,
            selectedLayerID: selectedLayerID
        )

        NSLog(
            "[Baram Motion] Selected layer: %@",
            id?.uuidString ?? "nil"
        )
    }

    // MARK: - Add Layers

    @objc
    private func addTextLayer() {

        let before =
            captureSnapshot()

        let count =
            layers.filter {
                $0.kind == .text
            }.count + 1

        let layer =
            LayerModel(
                kind: .text,
                name: "Text \(count)",
                color: NSColor.white,
                x: 760,
                y: 430,
                width: 400,
                height: 90,
                fontSize: 56,
                anchor: .topLeft,
                startTime: 0,
                duration: 5
            )

        layers.append(layer)
        selectedLayerID = layer.id

        finishMutation(
            before: before,
            actionName: "テキスト追加"
        )

        NSLog(
            "[Baram Motion] Text layer added: %@",
            layer.name
        )
    }

    @objc
    private func addRectangleLayer() {

        let before =
            captureSnapshot()

        let count =
            layers.filter {
                $0.kind == .rectangle
            }.count + 1

        let layer =
            LayerModel(
                kind: .rectangle,
                name: "Rectangle \(count)",
                color: NSColor.systemBlue,
                x: 750,
                y: 380,
                width: 420,
                height: 240,
                anchor: .topLeft,
                startTime: 0,
                duration: 5
            )

        layers.append(layer)
        selectedLayerID = layer.id

        finishMutation(
            before: before,
            actionName: "四角形追加"
        )

        NSLog(
            "[Baram Motion] Rectangle layer added: %@",
            layer.name
        )
    }

    @objc
    private func addToggleLayer() {

        let before =
            captureSnapshot()

        let count =
            layers.filter {
                $0.kind == .toggle
            }.count + 1

        let layer =
            LayerModel(
                kind: .toggle,
                name: "Switch \(count)",
                color: NSColor.systemBlue,
                x: 850,
                y: 420,
                width: 180,
                height: 100,
                anchor: .topLeft,
                startTime: 0,
                duration: 5,
                isOn: true
            )

        layers.append(layer)
        selectedLayerID = layer.id

        finishMutation(
            before: before,
            actionName: "Switch追加"
        )

        NSLog(
            "[Baram Motion] Switch layer added: %@",
            layer.name
        )
    }

    @objc
    private func deleteSelectedLayer() {

        guard let selectedLayerID else {

            NSLog(
                "[Baram Motion] WARNING: No layer selected for deletion."
            )

            return
        }

        guard layers.contains(where: {
            $0.id == selectedLayerID
        }) else {

            NSLog(
                "[Baram Motion] ERROR: Selected layer no longer exists."
            )

            return
        }

        let before =
            captureSnapshot()

        layers.removeAll {
            $0.id == selectedLayerID
        }

        self.selectedLayerID =
            layers.last?.id

        finishMutation(
            before: before,
            actionName: "レイヤー削除"
        )

        NSLog(
            "[Baram Motion] Layer deleted: %@",
            selectedLayerID.uuidString
        )
    }

    // MARK: - Undo / Redo

    @objc
    private func undoAction() {

        guard let manager =
                view.window?.undoManager,
              manager.canUndo else {

            NSLog(
                "[Baram Motion] Undo unavailable."
            )

            return
        }

        manager.undo()

        NSLog(
            "[Baram Motion] Undo executed."
        )
    }

    @objc
    private func redoAction() {

        guard let manager =
                view.window?.undoManager,
              manager.canRedo else {

            NSLog(
                "[Baram Motion] Redo unavailable."
            )

            return
        }

        manager.redo()

        NSLog(
            "[Baram Motion] Redo executed."
        )
    }

    // MARK: - Inspector Changes

    @objc
    private func colorChanged(
        _ sender: NSColorWell
    ) {

        guard let layer =
                selectedLayer else {

            NSLog(
                "[Baram Motion] ERROR: No selected layer for color change."
            )

            return
        }

        let before =
            captureSnapshot()

        layer.color =
            sender.color

        finishMutation(
            before: before,
            actionName: "カラー変更"
        )

        NSLog(
            "[Baram Motion] Color changed."
        )
    }

    @objc
    private func anchorChanged(
        _ sender: NSPopUpButton
    ) {

        guard let layer =
                selectedLayer else {

            NSLog(
                "[Baram Motion] ERROR: No selected layer for anchor change."
            )

            return
        }

        let newAnchor:
            PositionAnchor =
            sender.indexOfSelectedItem
                == PositionAnchor.center.rawValue
                ? .center
                : .topLeft

        guard layer.anchor != newAnchor else {
            return
        }

        let before =
            captureSnapshot()

        let currentFrame =
            frameForLayer(layer)

        layer.anchor =
            newAnchor

        let newPosition =
            positionForFrame(
                currentFrame,
                anchor: newAnchor
            )

        layer.x =
            newPosition.x

        layer.y =
            newPosition.y

        clampLayerPosition(layer)

        finishMutation(
            before: before,
            actionName: "基準位置変更"
        )

        NSLog(
            "[Baram Motion] Anchor changed: %@",
            newAnchor.displayName
        )
    }

    @objc
    private func positionFieldChanged(
        _ sender: NSTextField
    ) {

        guard let layer =
                selectedLayer else {

            NSLog(
                "[Baram Motion] ERROR: No selected layer for position change."
            )

            return
        }

        guard let value =
                Double(sender.stringValue),
              value.isFinite else {

            NSLog(
                "[Baram Motion] ERROR: Invalid position value."
            )

            refreshInspectorValues()

            return
        }

        let before =
            captureSnapshot()

        if sender === xField {
            layer.x = CGFloat(value)
        }

        if sender === yField {
            layer.y = CGFloat(value)
        }

        clampLayerPosition(layer)

        finishMutation(
            before: before,
            actionName: "位置変更"
        )

        NSLog(
            "[Baram Motion] Position changed: %.1f, %.1f",
            layer.x,
            layer.y
        )
    }

    @objc
    private func sizeFieldChanged(
        _ sender: NSTextField
    ) {

        guard let layer =
                selectedLayer else {

            NSLog(
                "[Baram Motion] ERROR: No selected layer for size change."
            )

            return
        }

        guard let value =
                Double(sender.stringValue),
              value.isFinite,
              value > 1 else {

            NSLog(
                "[Baram Motion] ERROR: Invalid size value."
            )

            refreshInspectorValues()

            return
        }

        let before =
            captureSnapshot()

        if sender === widthField {
            layer.width =
                CGFloat(value)
        }

        if sender === heightField {
            layer.height =
                CGFloat(value)
        }

        layer.width =
            max(1, layer.width)

        layer.height =
            max(1, layer.height)

        clampLayerPosition(layer)

        finishMutation(
            before: before,
            actionName: "サイズ変更"
        )

        NSLog(
            "[Baram Motion] Size changed: %.1f x %.1f",
            layer.width,
            layer.height
        )
    }

    @objc
    private func fontSizeChanged(
        _ sender: NSTextField
    ) {

        guard let layer =
                selectedLayer,
              layer.kind == .text else {

            NSLog(
                "[Baram Motion] ERROR: Invalid text layer for font change."
            )

            return
        }

        guard let value =
                Double(sender.stringValue),
              value.isFinite,
              value > 1 else {

            NSLog(
                "[Baram Motion] ERROR: Invalid font size."
            )

            refreshInspectorValues()

            return
        }

        let before =
            captureSnapshot()

        layer.fontSize =
            max(
                1,
                CGFloat(value)
            )

        finishMutation(
            before: before,
            actionName: "文字サイズ変更"
        )

        NSLog(
            "[Baram Motion] Font size changed: %.1f",
            layer.fontSize
        )
    }

    @objc
    private func switchStateChanged(
        _ sender: NSSwitchControl
    ) {

        guard let layer =
                selectedLayer,
              layer.kind == .toggle else {

            NSLog(
                "[Baram Motion] ERROR: Switch state changed for non-switch layer."
            )

            return
        }

        let before =
            captureSnapshot()

        layer.isOn =
            sender.isOn

        finishMutation(
            before: before,
            actionName: "Switch状態変更"
        )

        NSLog(
            "[Baram Motion] Switch state: %@",
            layer.isOn ? "ON" : "OFF"
        )
    }

    // MARK: - Undo Snapshot

    private func captureSnapshot()
        -> [UUID: LayerSnapshot] {

        var result:
            [UUID: LayerSnapshot] = [:]

        for layer in layers {

            result[layer.id] =
                LayerSnapshot(
                    layer:
                        layer.copyLayer()
                )
        }

        return result
    }

    private func finishMutation(
        before:
            [UUID: LayerSnapshot],
        actionName: String
    ) {

        guard !isRestoringUndoState else {

            refreshAll()

            return
        }

        let after =
            captureSnapshot()

        guard snapshotsDiffer(
            before,
            after
        ) else {

            refreshAll()

            return
        }

        registerUndo(
            before: before,
            actionName: actionName
        )

        refreshAll()
    }

    private func registerUndo(
        before:
            [UUID: LayerSnapshot],
        actionName: String
    ) {

        guard let manager =
                view.window?.undoManager else {

            NSLog(
                "[Baram Motion] WARNING: Undo manager unavailable."
            )

            return
        }

        manager.registerUndo(
            withTarget: self
        ) { [weak self] target in

            guard let self else {
                return
            }

            let current =
                self.captureSnapshot()

            self.restoreSnapshots(
                before
            )

            self.registerUndo(
                before: current,
                actionName: actionName
            )

            self.refreshAll()
        }

        manager.setActionName(
            actionName
        )
    }

    private func restoreSnapshots(
        _ snapshots:
            [UUID: LayerSnapshot]
    ) {

        isRestoringUndoState = true

        defer {
            isRestoringUndoState = false
        }

        var restoredLayers:
            [LayerModel] = []

        // Existing order
        for originalLayer in layers {

            if let snapshot =
                snapshots[originalLayer.id] {

                restoredLayers.append(
                    snapshot.layer.copyLayer()
                )
            }
        }

        // Restored layers which were newly created
        // in the snapshot.
        for snapshot in snapshots.values {

            let exists =
                restoredLayers.contains {
                    $0.id == snapshot.layer.id
                }

            if !exists {

                restoredLayers.append(
                    snapshot.layer.copyLayer()
                )
            }
        }

        layers =
            restoredLayers

        if let selectedLayerID,
           !layers.contains(where: {
               $0.id == selectedLayerID
           }) {

            self.selectedLayerID =
                layers.last?.id
        }
    }

    private func snapshotsDiffer(
        _ lhs:
            [UUID: LayerSnapshot],
        _ rhs:
            [UUID: LayerSnapshot]
    ) -> Bool {

        if lhs.count != rhs.count {
            return true
        }

        for id in lhs.keys {

            guard let left =
                    lhs[id]?.layer,
                  let right =
                    rhs[id]?.layer else {

                return true
            }

            if left.kind != right.kind ||
                left.name != right.name ||
                !left.color.isEqual(
                    right.color
                ) ||
                left.x != right.x ||
                left.y != right.y ||
                left.width != right.width ||
                left.height != right.height ||
                left.fontSize != right.fontSize ||
                left.anchor != right.anchor ||
                left.startTime != right.startTime ||
                left.duration != right.duration ||
                left.isOn != right.isOn {

                return true
            }
        }

        return false
    }

    // MARK: - Refresh

    private func refreshAll() {

        refreshPreview()
        refreshLayerList()
        refreshInspectorValues()
        refreshSelectionAppearance()
        updateTimelineSize()

        timelineContent.reload(
            layers:
                timelineProxies,
            selectedLayerID:
                selectedLayerID
        )
    }

    private var timelineProxies:
        [LayerModelProxy] {

        return layers.map {
            LayerModelProxy(
                id: $0.id,
                kindDisplayName:
                    $0.kind.displayName,
                name: $0.name,
                color: $0.color,
                startTime: $0.startTime,
                duration: $0.duration
            )
        }
    }

    // MARK: - Preview Rendering

    private func refreshPreview() {

        guard previewView != nil else {

            NSLog(
                "[Baram Motion] ERROR: Preview view is nil."
            )

            return
        }

        for elementView
            in previewElementViews.values {

            elementView.removeFromSuperview()
        }

        previewElementViews.removeAll(
            keepingCapacity: true
        )

        for layer in layers {

            let element =
                PreviewElementView(
                    layerID: layer.id,
                    kind: layer.kind
                )

            element.onSelect =
                { [weak self] id in

                    guard let self else {
                        return
                    }

                    self.selectLayer(id)
                }

            element.backgroundColor =
                layer.color

            element.fontSize =
                layer.fontSize

            element.text =
                layer.name

            element.isOn =
                layer.isOn

            element.frame =
                frameForLayer(layer)

            previewView.addSubview(
                element
            )

            previewElementViews[layer.id] =
                element

            element.updateAppearance(
                selected:
                    layer.id
                    == selectedLayerID
            )
        }
    }

    private func refreshSelectionAppearance() {

        for layer in layers {

            guard let element =
                    previewElementViews[layer.id] else {

                continue
            }

            element.updateAppearance(
                selected:
                    layer.id
                    == selectedLayerID
            )
        }
    }

    // MARK: - Inspector Refresh

    private func refreshInspectorValues() {

        guard let layer =
                selectedLayer else {

            rebuildInspector()

            return
        }

        colorWell?.color =
            layer.color

        anchorPopup?.selectItem(
            at:
                layer.anchor.rawValue
        )

        xField?.stringValue =
            formatNumber(layer.x)

        yField?.stringValue =
            formatNumber(layer.y)

        widthField?.stringValue =
            formatNumber(layer.width)

        heightField?.stringValue =
            formatNumber(layer.height)

        fontSizeField?.stringValue =
            formatNumber(
                layer.fontSize
            )

        switchStateControl?.isOn =
            layer.isOn
    }

    // MARK: - Geometry

    private func frameForLayer(
        _ layer: LayerModel
    ) -> NSRect {

        switch layer.anchor {

        case .topLeft:

            return NSRect(
                x:
                    layer.x,
                y:
                    Layout.previewHeight
                    - layer.y
                    - layer.height,
                width:
                    layer.width,
                height:
                    layer.height
            )

        case .center:

            return NSRect(
                x:
                    layer.x
                    - layer.width / 2,
                y:
                    Layout.previewHeight
                    - layer.y
                    - layer.height / 2,
                width:
                    layer.width,
                height:
                    layer.height
            )
        }
    }

    private func positionForFrame(
        _ frame: NSRect,
        anchor:
            PositionAnchor
    ) -> CGPoint {

        switch anchor {

        case .topLeft:

            return CGPoint(
                x:
                    frame.minX,
                y:
                    Layout.previewHeight
                    - frame.maxY
            )

        case .center:

            return CGPoint(
                x:
                    frame.midX,
                y:
                    Layout.previewHeight
                    - frame.midY
            )
        }
    }

    private func clampLayerPosition(
        _ layer: LayerModel
    ) {

        switch layer.anchor {

        case .topLeft:

            layer.x =
                max(
                    0,
                    min(
                        Layout.previewWidth
                        - layer.width,
                        layer.x
                    )
                )

            layer.y =
                max(
                    0,
                    min(
                        Layout.previewHeight
                        - layer.height,
                        layer.y
                    )
                )

        case .center:

            layer.x =
                max(
                    layer.width / 2,
                    min(
                        Layout.previewWidth
                        - layer.width / 2,
                        layer.x
                    )
                )

            layer.y =
                max(
                    layer.height / 2,
                    min(
                        Layout.previewHeight
                        - layer.height / 2,
                        layer.y
                    )
                )
        }
    }

    // MARK: - Timeline Size

    private func updateTimelineSize() {

        guard timelineContent != nil else {
            return
        }

        let maximumEnd =
            layers.reduce(
                CGFloat(0)
            ) {
                max(
                    $0,
                    $1.startTime
                    + $1.duration
                )
            }

        let requiredWidth =
            (maximumEnd + 5)
            * Layout.timelineScale

        let width =
            max(
                Layout.minimumTimelineWidth,
                requiredWidth
            )

        let rowHeight:
            CGFloat = 34

        let rulerHeight:
            CGFloat = 28

        let totalHeight =
            rulerHeight
            + max(
                1,
                CGFloat(layers.count)
            )
            * rowHeight
            + 16

        timelineContent.frame =
            NSRect(
                x: 0,
                y: 0,
                width: width,
                height: totalHeight
            )
    }

    // MARK: - Utils

    private func formatNumber(
        _ value: CGFloat
    ) -> String {

        if abs(
            value.rounded() - value
        ) < 0.001 {

            return String(
                Int(value.rounded())
            )
        }

        return String(
            format: "%.2f",
            Double(value)
        )
    }
}

// MARK: - Toolbar Delegate

extension MainViewController:
    NSToolbarDelegate {

    private enum ToolbarItemID {

        static let undo =
            NSToolbarItem.Identifier(
                "BaramMotion.Undo"
            )

        static let redo =
            NSToolbarItem.Identifier(
                "BaramMotion.Redo"
            )

        static let text =
            NSToolbarItem.Identifier(
                "BaramMotion.Text"
            )

        static let rectangle =
            NSToolbarItem.Identifier(
                "BaramMotion.Rectangle"
            )

        static let toggle =
            NSToolbarItem.Identifier(
                "BaramMotion.Toggle"
            )

        static let flexible =
            NSToolbarItem.Identifier
                .flexibleSpace
    }

    func toolbarAllowedItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [
        NSToolbarItem.Identifier
    ] {

        return [
            ToolbarItemID.undo,
            ToolbarItemID.redo,
            ToolbarItemID.flexible,
            ToolbarItemID.text,
            ToolbarItemID.rectangle,
            ToolbarItemID.toggle
        ]
    }

    func toolbarDefaultItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [
        NSToolbarItem.Identifier
    ] {

        return [
            ToolbarItemID.undo,
            ToolbarItemID.redo,
            ToolbarItemID.flexible,
            ToolbarItemID.text,
            ToolbarItemID.rectangle,
            ToolbarItemID.toggle
        ]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier
            itemIdentifier:
                NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag:
            Bool
    ) -> NSToolbarItem? {

        switch itemIdentifier {

        case ToolbarItemID.undo:

            let item =
                NSToolbarItem(
                    itemIdentifier:
                        itemIdentifier
                )

            item.label =
                "Undo"

            item.paletteLabel =
                "Undo"

            item.toolTip =
                "Undo"

            item.image =
                NSImage(
                    systemSymbolName:
                        "arrow.uturn.backward",
                    accessibilityDescription:
                        "Undo"
                )

            item.target =
                self

            item.action =
                #selector(
                    undoAction
                )

            return item

        case ToolbarItemID.redo:

            let item =
                NSToolbarItem(
                    itemIdentifier:
                        itemIdentifier
                )

            item.label =
                "Redo"

            item.paletteLabel =
                "Redo"

            item.toolTip =
                "Redo"

            item.image =
                NSImage(
                    systemSymbolName:
                        "arrow.uturn.forward",
                    accessibilityDescription:
                        "Redo"
                )

            item.target =
                self

            item.action =
                #selector(
                    redoAction
                )

            return item

        case ToolbarItemID.text:

            let item =
                NSToolbarItem(
                    itemIdentifier:
                        itemIdentifier
                )

            item.label =
                "テキスト"

            item.paletteLabel =
                "テキスト"

            item.toolTip =
                "テキストを追加"

            item.image =
                NSImage(
                    systemSymbolName:
                        "textformat",
                    accessibilityDescription:
                        "Text"
                )

            item.target =
                self

            item.action =
                #selector(
                    addTextLayer
                )

            return item

        case ToolbarItemID.rectangle:

            let item =
                NSToolbarItem(
                    itemIdentifier:
                        itemIdentifier
                )

            item.label =
                "四角形"

            item.paletteLabel =
                "四角形"

            item.toolTip =
                "四角形を追加"

            item.image =
                NSImage(
                    systemSymbolName:
                        "square",
                    accessibilityDescription:
                        "Rectangle"
                )

            item.target =
                self

            item.action =
                #selector(
                    addRectangleLayer
                )

            return item

        case ToolbarItemID.toggle:

            let item =
                NSToolbarItem(
                    itemIdentifier:
                        itemIdentifier
                )

            item.label =
                "Switch"

            item.paletteLabel =
                "Switch"

            item.toolTip =
                "Switchを追加"

            item.image =
                NSImage(
                    systemSymbolName:
                        "switch.2",
                    accessibilityDescription:
                        "Switch"
                )

            item.target =
                self

            item.action =
                #selector(
                    addToggleLayer
                )

            return item

        default:

            return nil
        }
    }
}

// MARK: - Timeline Delegate

extension MainViewController:
    TimelineContentViewDelegate {

    func timelineContentView(
        _ view: TimelineContentView,
        didSelectLayer id: UUID
    ) {

        selectLayer(id)
    }

    func timelineContentView(
        _ view: TimelineContentView,
        didBeginEditingLayer id: UUID
    ) {

        guard let layer =
                layers.first(where: {
                    $0.id == id
                }) else {

            NSLog(
                "[Baram Motion] ERROR: Timeline edit layer not found."
            )

            return
        }

        timelineEditBeforeSnapshot = [
            id:
                LayerSnapshot(
                    layer:
                        layer.copyLayer()
                )
        ]

        NSLog(
            "[Baram Motion] Timeline edit begin: %@",
            layer.name
        )
    }

    func timelineContentView(
        _ view: TimelineContentView,
        didChangeLayer id: UUID,
        startTime: CGFloat,
        duration: CGFloat
    ) {

        guard let layer =
                layers.first(where: {
                    $0.id == id
                }) else {

            NSLog(
                "[Baram Motion] ERROR: Timeline layer not found."
            )

            return
        }

        layer.startTime =
            max(
                0,
                startTime
            )

        layer.duration =
            max(
                0.25,
                duration
            )

        updateTimelineSize()

        timelineContent.reload(
            layers:
                timelineProxies,
            selectedLayerID:
                selectedLayerID
        )

        NSLog(
            "[Baram Motion] Timeline changed %@: start %.2f / duration %.2f",
            layer.name,
            layer.startTime,
            layer.duration
        )
    }

    func timelineContentView(
        _ view: TimelineContentView,
        didFinishEditingLayer id: UUID
    ) {

        guard !timelineEditBeforeSnapshot.isEmpty else {
            return
        }

        let current =
            captureSnapshot()

        var changed =
            false

        for (id, before)
            in timelineEditBeforeSnapshot {

            guard let after =
                    current[id]?.layer else {

                changed = true
                break
            }

            if before.layer.startTime
                    != after.startTime
                ||
                before.layer.duration
                    != after.duration {

                changed = true
                break
            }
        }

        if changed {

            registerUndo(
                before:
                    timelineEditBeforeSnapshot,
                actionName:
                    "タイムライン編集"
            )
        }

        timelineEditBeforeSnapshot.removeAll()

        refreshAll()

        NSLog(
            "[Baram Motion] Timeline edit finished."
        )
    }
}

// MARK: - Preview Scroll View

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

final class PreviewCanvasView:
    NSView {

    weak var previewView: NSView?
}

// MARK: - Preview Element

final class PreviewElementView:
    NSView {

    let layerID: UUID
    let kind: MainViewController.LayerKind

    var backgroundColor:
        NSColor = .white

    var fontSize:
        CGFloat = 48

    var text:
        String = ""

    var isOn:
        Bool = true

    var onSelect:
        ((UUID) -> Void)?

    init(
        layerID: UUID,
        kind:
            MainViewController.LayerKind
    ) {

        self.layerID =
            layerID

        self.kind =
            kind

        super.init(
            frame: .zero
        )

        wantsLayer =
            true

        layer?.cornerRadius =
            6
    }

    required init?(
        coder:
            NSCoder
    ) {

        return nil
    }

    override func draw(
        _ dirtyRect: NSRect
    ) {

        super.draw(
            dirtyRect
        )

        switch kind {

        case .text:

            drawText()

        case .rectangle:

            drawRectangle()

        case .toggle:

            drawToggle()
        }
    }

    private func drawText() {

        let attributes:
            [NSAttributedString.Key: Any] = [
                .font:
                    NSFont.systemFont(
                        ofSize:
                            fontSize,
                        weight:
                            .medium
                    ),

                .foregroundColor:
                    backgroundColor
            ]

        let string =
            NSString(
                string:
                    text
            )

        let size =
            string.size(
                withAttributes:
                    attributes
            )

        let rect =
            NSRect(
                x: 0,
                y:
                    max(
                        0,
                        (bounds.height
                         - size.height)
                        / 2
                    ),
                width:
                    bounds.width,
                height:
                    size.height
            )

        string.draw(
            in: rect,
            withAttributes:
                attributes
        )
    }

    private func drawRectangle() {

        backgroundColor.setFill()

        let path =
            NSBezierPath(
                roundedRect:
                    bounds,
                xRadius:
                    8,
                yRadius:
                    8
            )

        path.fill()
    }

    private func drawToggle() {

        let trackRect =
            bounds.insetBy(
                dx:
                    bounds.width
                    * 0.08,
                dy:
                    bounds.height
                    * 0.25
            )

        let radius =
            trackRect.height / 2

        let trackPath =
            NSBezierPath(
                roundedRect:
                    trackRect,
                xRadius:
                    radius,
                yRadius:
                    radius
            )

        let trackColor:
            NSColor =
            isOn
            ? backgroundColor
            : NSColor.disabledControlTextColor

        trackColor.setFill()

        trackPath.fill()

        let knobDiameter =
            trackRect.height * 0.78

        let knobX:
            CGFloat =
            isOn
            ? trackRect.maxX
                - knobDiameter
                - 5
            : trackRect.minX
                + 5

        let knobRect =
            NSRect(
                x:
                    knobX,
                y:
                    trackRect.minY
                    + (
                        trackRect.height
                        - knobDiameter
                    ) / 2,
                width:
                    knobDiameter,
                height:
                    knobDiameter
            )

        NSColor.controlBackgroundColor.setFill()

        NSBezierPath(
            ovalIn:
                knobRect
        ).fill()
    }

    func updateAppearance(
        selected: Bool
    ) {

        layer?.borderWidth =
            selected
            ? 2
            : 0

        layer?.borderColor =
            selected
            ? NSColor.controlAccentColor.cgColor
            : nil

        needsDisplay =
            true
    }

    override func mouseDown(
        with event: NSEvent
    ) {

        onSelect?(
            layerID
        )

        NSLog(
            "[Baram Motion] Preview layer selected: %@",
            layerID.uuidString
        )

        super.mouseDown(
            with: event
        )
    }
}

// MARK: - Timeline Delegate

protocol TimelineContentViewDelegate:
    AnyObject {

    func timelineContentView(
        _ view:
            TimelineContentView,
        didSelectLayer id:
            UUID
    )

    func timelineContentView(
        _ view:
            TimelineContentView,
        didBeginEditingLayer id:
            UUID
    )

    func timelineContentView(
        _ view:
            TimelineContentView,
        didChangeLayer id:
            UUID,
        startTime:
            CGFloat,
        duration:
            CGFloat
    )

    func timelineContentView(
        _ view:
            TimelineContentView,
        didFinishEditingLayer id:
            UUID
    )
}

// MARK: - Timeline Content

final class TimelineContentView:
    NSView {

    weak var delegate:
        TimelineContentViewDelegate?

    private var layers:
        [MainViewController.LayerModelProxy]
        = []

    private var selectedLayerID:
        UUID?

    private let rulerHeight:
        CGFloat = 28

    private let rowHeight:
        CGFloat = 34

    private let timelineScale:
        CGFloat = 90

    private enum Interaction {
        case none
        case move
        case resizeLeft
        case resizeRight
    }

    private var interaction:
        Interaction = .none

    private var activeLayerID:
        UUID?

    private var dragStartMouseX:
        CGFloat = 0

    private var originalStartTime:
        CGFloat = 0

    private var originalDuration:
        CGFloat = 0

    private let edgeHitWidth:
        CGFloat = 8

    private let minimumDuration:
        CGFloat = 0.25

    override var isFlipped:
        Bool {
        return false
    }

    func reload(
        layers:
            [MainViewController.LayerModelProxy],
        selectedLayerID:
            UUID?
    ) {

        self.layers =
            layers

        self.selectedLayerID =
            selectedLayerID

        needsDisplay =
            true
    }

    override func draw(
        _ dirtyRect: NSRect
    ) {

        super.draw(
            dirtyRect
        )

        guard let context =
                NSGraphicsContext
                    .current?
                    .cgContext else {

            NSLog(
                "[Baram Motion] ERROR: Timeline graphics context is nil."
            )

            return
        }

        drawBackground()
        drawRuler(
            context
        )
        drawRows(
            context
        )
    }

    private func drawBackground() {

        NSColor.controlBackgroundColor.setFill()

        bounds.fill()
    }

    private func drawRuler(
        _ context:
            CGContext
    ) {

        let topY =
            bounds.height
            - rulerHeight

        NSColor.underPageBackgroundColor
            .setFill()

        NSRect(
            x: 0,
            y: topY,
            width: bounds.width,
            height: rulerHeight
        ).fill()

        NSColor.separatorColor
            .setStroke()

        context.setLineWidth(
            1
        )

        var second:
            CGFloat = 0

        while second
                * timelineScale
                < bounds.width {

            let x =
                second
                * timelineScale

            let isMajor =
                Int(second) % 5 == 0

            let markHeight:
                CGFloat =
                isMajor
                ? 14
                : 8

            context.move(
                to:
                    CGPoint(
                        x: x,
                        y: topY
                    )
            )

            context.addLine(
                to:
                    CGPoint(
                        x: x,
                        y:
                            topY
                            + markHeight
                    )
            )

            context.strokePath()

            if isMajor {

                let attributes:
                    [NSAttributedString.Key: Any] = [
                        .font:
                            NSFont.monospacedSystemFont(
                                ofSize: 10,
                                weight: .regular
                            ),

                        .foregroundColor:
                            NSColor.secondaryLabelColor
                    ]

                let label =
                    NSString(
                        string:
                            String(
                                format:
                                    "%.0fs",
                                Double(second)
                            )
                    )

                label.draw(
                    at:
                        NSPoint(
                            x:
                                x + 4,
                            y:
                                topY + 8
                        ),
                    withAttributes:
                        attributes
                )
            }

            second += 1
        }

        context.move(
            to:
                CGPoint(
                    x: 0,
                    y: topY
                )
        )

        context.addLine(
            to:
                CGPoint(
                    x: bounds.width,
                    y: topY
                )
        )

        context.strokePath()
    }

    private func drawRows(
        _ context:
            CGContext
    ) {

        let firstRowY =
            bounds.height
            - rulerHeight
            - rowHeight

        for index in layers.indices {

            let rowY =
                firstRowY
                - CGFloat(index)
                * rowHeight

            let rowRect =
                NSRect(
                    x: 0,
                    y: rowY,
                    width: bounds.width,
                    height: rowHeight
                )

            if index % 2 == 0 {

                NSColor.controlBackgroundColor
                    .setFill()

            } else {

                NSColor.underPageBackgroundColor
                    .setFill()
            }

            rowRect.fill()

            let layer =
                layers[index]

            let clipX =
                layer.startTime
                * timelineScale

            let clipWidth =
                max(
                    20,
                    layer.duration
                    * timelineScale
                )

            let clipRect =
                NSRect(
                    x: clipX,
                    y: rowY + 5,
                    width: clipWidth,
                    height: rowHeight - 10
                )

            let selected =
                layer.id
                == selectedLayerID

            let clipColor =
                layer.color.withAlphaComponent(
                    selected
                    ? 0.88
                    : 0.66
                )

            clipColor.setFill()

            let clipPath =
                NSBezierPath(
                    roundedRect:
                        clipRect,
                    xRadius:
                        6,
                    yRadius:
                        6
                )

            clipPath.fill()

            if selected {

                NSColor.controlAccentColor
                    .setStroke()

                clipPath.lineWidth =
                    2

                clipPath.stroke()
            }

            let title =
                NSString(
                    string:
                        "\(layer.kindDisplayName)  \(layer.name)"
                )

            let attributes:
                [NSAttributedString.Key: Any] = [
                    .font:
                        NSFont.systemFont(
                            ofSize: 11,
                            weight:
                                selected
                                ? .semibold
                                : .medium
                        ),

                    .foregroundColor:
                        NSColor.white
                ]

            title.draw(
                in:
                    clipRect.insetBy(
                        dx: 10,
                        dy: 6
                    ),
                withAttributes:
                    attributes
            )
        }
    }

    override func mouseDown(
        with event: NSEvent
    ) {

        let location =
            convert(
                event.locationInWindow,
                from: nil
            )

        guard let hit =
                hitTestLayer(
                    at: location
                ) else {

            interaction =
                .none

            activeLayerID =
                nil

            return
        }

        selectedLayerID =
            hit.layer.id

        delegate?.timelineContentView(
            self,
            didSelectLayer:
                hit.layer.id
        )

        activeLayerID =
            hit.layer.id

        dragStartMouseX =
            location.x

        originalStartTime =
            hit.layer.startTime

        originalDuration =
            hit.layer.duration

        let localX =
            location.x
            - hit.rect.minX

        if localX
                <= edgeHitWidth {

            interaction =
                .resizeLeft

        } else if localX
                    >= hit.rect.width
                    - edgeHitWidth {

            interaction =
                .resizeRight

        } else {

            interaction =
                .move
        }

        delegate?.timelineContentView(
            self,
            didBeginEditingLayer:
                hit.layer.id
        )

        NSLog(
            "[Baram Motion] Timeline editing started: %@",
            hit.layer.name
        )
    }

    override func mouseDragged(
        with event: NSEvent
    ) {

        guard interaction != .none,
              let activeLayerID,
              let active =
                layers.first(where: {
                    $0.id
                    == activeLayerID
                }) else {

            return
        }

        let location =
            convert(
                event.locationInWindow,
                from: nil
            )

        let deltaPixels =
            location.x
            - dragStartMouseX

        let deltaTime =
            deltaPixels
            / timelineScale

        var newStart =
            originalStartTime

        var newDuration =
            originalDuration

        switch interaction {

        case .move:

            newStart =
                max(
                    0,
                    originalStartTime
                    + deltaTime
                )

        case .resizeLeft:

            let requestedStart =
                originalStartTime
                + deltaTime

            let maximumStart =
                originalStartTime
                + originalDuration
                - minimumDuration

            newStart =
                max(
                    0,
                    min(
                        maximumStart,
                        requestedStart
                    )
                )

            newDuration =
                originalDuration
                - (
                    newStart
                    - originalStartTime
                )

        case .resizeRight:

            newDuration =
                max(
                    minimumDuration,
                    originalDuration
                    + deltaTime
                )

        case .none:
            break
        }

        delegate?.timelineContentView(
            self,
            didChangeLayer:
                active.id,
            startTime:
                newStart,
            duration:
                newDuration
        )
    }

    override func mouseUp(
        with event: NSEvent
    ) {

        if let activeLayerID {

            delegate?.timelineContentView(
                self,
                didFinishEditingLayer:
                    activeLayerID
            )
        }

        interaction =
            .none

        activeLayerID =
            nil

        NSLog(
            "[Baram Motion] Timeline editing finished."
        )
    }

    private func hitTestLayer(
        at point:
            CGPoint
    ) -> (
        layer:
            MainViewController.LayerModelProxy,
        rect:
            NSRect
    )? {

        let firstRowY =
            bounds.height
            - rulerHeight
            - rowHeight

        for index in layers.indices {

            let rowY =
                firstRowY
                - CGFloat(index)
                * rowHeight

            let layer =
                layers[index]

            let rect =
                NSRect(
                    x:
                        layer.startTime
                        * timelineScale,
                    y:
                        rowY + 5,
                    width:
                        max(
                            20,
                            layer.duration
                            * timelineScale
                        ),
                    height:
                        rowHeight - 10
                )

            if rect.contains(point) {

                return (
                    layer:
                        layer,
                    rect:
                        rect
                )
            }
        }

        return nil
    }
}

// MARK: - Layer List Button

final class LayerListButton:
    NSButton {

    var layerID:
        UUID?
}

// MARK: - Switch Control

final class NSSwitchControl:
    NSButton {

    var isOn:
        Bool {
        didSet {
            state =
                isOn
                ? .on
                : .off
        }
    }

    init(
        isOn:
            Bool
    ) {

        self.isOn =
            isOn

        super.init(
            frame:
                .zero
        )

        setButtonType(
            .switch
        )

        title =
            ""

        controlSize =
            .small

        widthAnchor.constraint(
            equalToConstant:
                40
        ).isActive =
            true

        heightAnchor.constraint(
            equalToConstant:
                22
        ).isActive =
            true

        state =
            isOn
            ? .on
            : .off
    }

    required init?(
        coder:
            NSCoder
    ) {

        return nil
    }

    override func mouseDown(
        with event:
            NSEvent
    ) {

        super.mouseDown(
            with:
                event
        )

        isOn =
            state == .on

        NSLog(
            "[Baram Motion] Switch changed: %@",
            isOn ? "ON" : "OFF"
        )
    }
}