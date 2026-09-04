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
        switchWidthField = nil
        switchHeightField = nil
        cornerRadiusField = nil
        textContentField = nil
        switchStateHostingView = nil
        keyframeButtons.removeAll()
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
            makeAnimatedRow(
                title: "カラー",
                control: colorControl,
                property: .color,
                layer: layer
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

        // X / Y / Width / Height
        let evaluated = evaluatedTransform(for: layer, frame: playbackController.currentFrame)
        addAnimatedNumericRow(stack: stack, title: "X", fieldValue: evaluated.x, property: .x, action: #selector(positionFieldChanged(_:)), targetField: &xField, layer: layer)
        addAnimatedNumericRow(stack: stack, title: "Y", fieldValue: evaluated.y, property: .y, action: #selector(positionFieldChanged(_:)), targetField: &yField, layer: layer)
        addAnimatedNumericRow(stack: stack, title: "幅", fieldValue: evaluated.width, property: .width, action: #selector(sizeFieldChanged(_:)), targetField: &widthField, layer: layer)
        addAnimatedNumericRow(stack: stack, title: "高さ", fieldValue: evaluated.height, property: .height, action: #selector(sizeFieldChanged(_:)), targetField: &heightField, layer: layer)
        let cornerField = makeNumericField(evaluatedCornerRadius(for: layer, frame: playbackController.currentFrame))
        cornerField.target = self; cornerField.action = #selector(cornerRadiusChanged(_:)); cornerRadiusField = cornerField
        stack.addArrangedSubview(makeAnimatedRow(title: "角丸", control: cornerField, property: .cornerRadius, layer: layer))

        if layer.kind == .text {
            let textField = NSTextField(string: evaluatedText(for: layer, frame: playbackController.currentFrame))
            textField.font = NSFont.systemFont(ofSize: 12)
            textField.usesSingleLineMode = false
            textField.lineBreakMode = .byTruncatingTail
            textField.target = self
            textField.action = #selector(textContentChanged(_:))
            textField.widthAnchor.constraint(equalToConstant: 120).isActive = true
            textContentField = textField
            stack.addArrangedSubview(makeAnimatedRow(title: "内容", control: textField, property: .text, layer: layer))
        }

        if layer.kind == .toggle {
            let panelState = PanelSwitchEditorView(
                isOn: Binding(get: { [weak self] in
                    guard let self, let id = self.selectedLayerID, let target = self.layers.first(where: { $0.id == id }) else { return false }
                    return self.evaluatedSwitchState(for: target, frame: self.playbackController.currentFrame)
                }, set: { [weak self] value in
                    guard let self, let id = self.selectedLayerID else { return }
                    self.setSwitchState(for: id, isOn: value)
                })
            )
            let host = NSHostingView(rootView: panelState)
            host.translatesAutoresizingMaskIntoConstraints = false
            host.widthAnchor.constraint(equalToConstant: 44).isActive = true
            host.heightAnchor.constraint(equalToConstant: 28).isActive = true
            switchStateHostingView = host
            stack.addArrangedSubview(makeAnimatedRow(title: "状態", control: host, property: .isOn, layer: layer))

        }

        if layer.kind == .text {
            let fontControl = makeNumericField(layer.fontSize)
            fontControl.target = self; fontControl.action = #selector(fontSizeChanged(_:)); fontSizeField = fontControl
            stack.addArrangedSubview(makeInspectorRow(title: "文字サイズ", control: fontControl))
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

    @objc func cornerRadiusChanged(_ sender: NSTextField) {
        guard let layer = selectedLayer, layer.kind == .rectangle else { NSLog("[Baram Motion] ERROR: Corner radius requires rectangle layer."); return }
        guard let number = Double(sender.stringValue), number.isFinite, number >= 0 else { refreshInspectorValues(); NSLog("[Baram Motion] ERROR: Invalid corner radius."); return }
        let before = captureSnapshot(); let frame = playbackController.currentFrame; let value = max(0, CGFloat(number))
        if let idx = layer.propertyKeyframes.firstIndex(where: { $0.property == .cornerRadius && $0.frame == frame }) { layer.propertyKeyframes[idx].scalar = value }
        else if layer.propertyKeyframes.contains(where: { $0.property == .cornerRadius }) { layer.propertyKeyframes.append(.scalar(.cornerRadius, frame: frame, value: value)); normalizeKeyframes(layer) }
        else { layer.cornerRadius = value }
        finishMutation(before: before, actionName: "角丸変更"); refreshAll(); NSLog("[Baram Motion] Corner radius changed %.1f", value)
    }

    func makeAnimatedRow(title: String, control: NSView, property: AnimatedProperty, layer: LayerModel? = nil) -> NSView {
        let row = NSStackView(); row.orientation = .horizontal; row.alignment = .centerY; row.spacing = 6
        let label = NSTextField(labelWithString: title); label.font = NSFont.systemFont(ofSize: 11); label.textColor = NSColor.secondaryLabelColor
        label.widthAnchor.constraint(equalToConstant: 70).isActive = true
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let hasKey = layer.map { keyframeFor(property: property, layer: $0, frame: playbackController.currentFrame) } ?? false
        let key = NSButton(title: hasKey ? "◆" : "◇", target: self, action: #selector(toggleKeyframeForProperty(_:)))
        key.identifier = NSUserInterfaceItemIdentifier(property.rawValue)
        key.bezelStyle = .inline; key.isBordered = false; key.font = NSFont.systemFont(ofSize: 12); key.toolTip = "現在フレームに\(property.rawValue)キーフレーム"
        key.widthAnchor.constraint(equalToConstant: 22).isActive = true
        keyframeButtons[property] = key
        row.addArrangedSubview(label); row.addArrangedSubview(control); row.addArrangedSubview(key)
        return row
    }

    func addAnimatedNumericRow(stack: NSStackView, title: String, fieldValue: CGFloat, property: AnimatedProperty, action: Selector, targetField: inout NSTextField?, layer: LayerModel) {
        let field = makeNumericField(fieldValue); field.target = self; field.action = action; targetField = field
        stack.addArrangedSubview(makeAnimatedRow(title: title, control: field, property: property, layer: layer))
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
