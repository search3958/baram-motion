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

    func createPreviewScrollView()
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

    func createTimelinePanel()
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

    func createFloatingPanel(
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

    func createLeftPanelContent() {

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

    func refreshLayerList() {

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
    func layerListButtonPressed(
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
}
