import AppKit
import SwiftUI
import Combine

extension MainViewController {

    // MARK: - Right Panel

    func createRightPanelContent() {

        let playbackView =
            NSHostingView(
                rootView:
                    PlaybackControlsView(
                        controller: playbackController,
                        onCurrentFrameChanged: { [weak self] frame in
                            self?.playbackFrameChanged(frame)
                        }
                    )
            )

        playbackView.translatesAutoresizingMaskIntoConstraints = false
        playbackHostingView = playbackView
        rightContentView.addSubview(playbackView)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        rightContentView.addSubview(separator)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        inspectorStack = NSStackView()
        inspectorStack.orientation = .vertical
        inspectorStack.alignment = .leading
        inspectorStack.spacing = 10
        inspectorStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = inspectorStack
        rightContentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            playbackView.leadingAnchor.constraint(equalTo: rightContentView.leadingAnchor, constant: 16),
            playbackView.trailingAnchor.constraint(equalTo: rightContentView.trailingAnchor, constant: -16),
            playbackView.topAnchor.constraint(equalTo: rightContentView.topAnchor, constant: 12),
            playbackView.heightAnchor.constraint(equalToConstant: 116),

            separator.leadingAnchor.constraint(equalTo: rightContentView.leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: rightContentView.trailingAnchor, constant: -16),
            separator.topAnchor.constraint(equalTo: playbackView.bottomAnchor, constant: 8),

            scrollView.leadingAnchor.constraint(equalTo: rightContentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: rightContentView.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: rightContentView.bottomAnchor, constant: -12),
            inspectorStack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])

        inspectorScrollView = scrollView
        rebuildInspector()
    }

    func rebuildInspector() {

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

        // Switch state is edited directly in the preview via the native SwiftUI Toggle.
        // Keep panel 2 focused on playback and numeric transform settings.

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

    func makeInspectorRow(
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

    func makeNumericField(
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
}
