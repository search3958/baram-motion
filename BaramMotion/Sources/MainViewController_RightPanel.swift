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

        let timelineZoom = makeNumericField(timelinePixelsPerSecond)
        timelineZoom.target = self
        timelineZoom.action = #selector(timelineScaleChanged(_:))
        timelineZoom.minimum = 20
        timelineZoom.maximum = 600
        timelineZoom.step = 5
        timelineZoom.translatesAutoresizingMaskIntoConstraints = false
        rightContentView.addSubview(timelineZoom)

        let timelineZoomRow = makeInspectorRow(title: "タイムライン幅 / 秒", control: timelineZoom)
        timelineZoomRow.translatesAutoresizingMaskIntoConstraints = false
        rightContentView.addSubview(timelineZoomRow)

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
            timelineZoomRow.leadingAnchor.constraint(equalTo: rightContentView.leadingAnchor, constant: 16),
            timelineZoomRow.trailingAnchor.constraint(equalTo: rightContentView.trailingAnchor, constant: -16),
            timelineZoomRow.topAnchor.constraint(equalTo: playbackView.bottomAnchor, constant: 2),
            timelineZoomRow.heightAnchor.constraint(equalToConstant: 24),

            separator.leadingAnchor.constraint(equalTo: rightContentView.leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: rightContentView.trailingAnchor, constant: -16),
            separator.topAnchor.constraint(equalTo: timelineZoomRow.bottomAnchor, constant: 8),

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
        fontPopup = nil
        scaleXField = nil
        scaleYField = nil
        rotationField = nil
        opacityField = nil
        borderWidthField = nil
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

        anchorControl.addItems(withTitles: PositionAnchor.allCases.map(\.displayName))

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
        addAnimatedNumericRow(stack: stack, title: "Xスケール", fieldValue: evaluated.scaleX, property: .scaleX, action: #selector(transformFieldChanged(_:)), targetField: &scaleXField, layer: layer)
        addAnimatedNumericRow(stack: stack, title: "Yスケール", fieldValue: evaluated.scaleY, property: .scaleY, action: #selector(transformFieldChanged(_:)), targetField: &scaleYField, layer: layer)
        addAnimatedNumericRow(stack: stack, title: "角度", fieldValue: evaluated.rotation, property: .rotation, action: #selector(transformFieldChanged(_:)), targetField: &rotationField, layer: layer)
        let cornerField = makeNumericField(evaluatedCornerRadius(for: layer, frame: playbackController.currentFrame))
        cornerField.target = self; cornerField.action = #selector(cornerRadiusChanged(_:)); cornerRadiusField = cornerField
        stack.addArrangedSubview(makeAnimatedRow(title: "角丸", control: cornerField, property: .cornerRadius, layer: layer))

        let opacityControl = makeNumericField(evaluatedOpacity(for: layer, frame: playbackController.currentFrame) * 100); opacityControl.target=self; opacityControl.action=#selector(opacityChanged(_:)); opacityControl.minimum=0; opacityControl.maximum=100; opacityControl.step=1; opacityField=opacityControl
        stack.addArrangedSubview(makeAnimatedRow(title:"透明度 %", control:opacityControl, property:.opacity, layer:layer))

        let borderControl = makeNumericField(layer.borderWidth); borderControl.target=self; borderControl.action=#selector(borderWidthChanged(_:)); borderControl.minimum=0; borderControl.step=1; borderWidthField=borderControl
        stack.addArrangedSubview(makeAnimatedRow(title:"枠線太さ", control:borderControl, property:.borderWidth, layer:layer))
        let borderColor = NSColorWell(); borderColor.color=layer.borderColor; borderColor.target=self; borderColor.action=#selector(borderColorChanged(_:))
        stack.addArrangedSubview(makeInspectorRow(title:"枠線カラー", control:borderColor))
        let borderPos = NSPopUpButton(); borderPos.addItems(withTitles:StrokePosition.allCases.map(\.displayName)); borderPos.selectItem(at:layer.borderPosition.rawValue); borderPos.target=self; borderPos.action=#selector(borderPositionChanged(_:))
        stack.addArrangedSubview(makeInspectorRow(title:"枠線位置", control:borderPos))

        if layer.kind == .text {
            let textField = NSTextField(string: evaluatedText(for: layer, frame: playbackController.currentFrame))
            textField.font = NSFont.systemFont(ofSize: 12)
            textField.usesSingleLineMode = false
            textField.lineBreakMode = .byTruncatingTail
            textField.target = self
            textField.action = #selector(textContentChanged(_:))
            textField.widthAnchor.constraint(equalToConstant: 180).isActive = true
            textField.heightAnchor.constraint(equalToConstant: 72).isActive = true
            textField.cell?.wraps = true
            textField.cell?.isScrollable = false
            textContentField = textField
            stack.addArrangedSubview(makeAnimatedRow(title: "内容", control: textField, property: .text, layer: layer))
            let h = NSPopUpButton(); h.addItems(withTitles:TextHorizontalAlignment.allCases.map(\.displayName)); h.selectItem(at:layer.textHorizontalAlignment.rawValue); h.target=self; h.action=#selector(textHorizontalAlignmentChanged(_:)); stack.addArrangedSubview(makeInspectorRow(title:"横位置",control:h))
            let v = NSPopUpButton(); v.addItems(withTitles:TextVerticalAlignment.allCases.map(\.displayName)); v.selectItem(at:layer.textVerticalAlignment.rawValue); v.target=self; v.action=#selector(textVerticalAlignmentChanged(_:)); stack.addArrangedSubview(makeInspectorRow(title:"縦位置",control:v))
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

            let popup = NSPopUpButton()
            for family in NSFontManager.shared.availableFontFamilies.sorted() {
                let item = NSMenuItem(title: family, action: nil, keyEquivalent: "")
                item.representedObject = family
                popup.menu?.addItem(item)
            }
            let evaluatedFont = evaluatedFontName(for: layer, frame: playbackController.currentFrame)
            popup.selectItem(withTitle: evaluatedFont)
            popup.target = self
            popup.action = #selector(fontChanged(_:))
            popup.widthAnchor.constraint(equalToConstant: 170).isActive = true
            fontPopup = popup
            stack.addArrangedSubview(makeAnimatedRow(title: "フォント", control: popup, property: .font, layer: layer))
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

    @objc func borderWidthChanged(_ sender:NSTextField){ guard let layer=selectedLayer else{return}; guard let n=Double(sender.stringValue),n.isFinite else{refreshInspectorValues();return}; let v=max(0,CGFloat(n)); let f=playbackController.currentFrame;let b=captureSnapshot(); if let i=layer.propertyKeyframes.firstIndex(where: { $0.property == .borderWidth && $0.frame == f }){layer.propertyKeyframes[i].scalar=v}else if layer.propertyKeyframes.contains(where: { $0.property == .borderWidth }){layer.propertyKeyframes.append(.scalar(.borderWidth,frame:f,value:v));normalizeKeyframes(layer)}else{layer.borderWidth=v};finishMutation(before:b,actionName:"枠線太さ変更");refreshAll();NSLog("[Baram Motion] Border width changed %.2f",Double(v)) }
    @objc func borderColorChanged(_ sender:NSColorWell){ guard let layer=selectedLayer else{return};let b=captureSnapshot();layer.borderColor=sender.color;finishMutation(before:b,actionName:"枠線カラー変更");refreshAll();NSLog("[Baram Motion] Border color changed.") }
    @objc func borderPositionChanged(_ sender:NSPopUpButton){ guard let layer=selectedLayer,let p=StrokePosition(rawValue:sender.indexOfSelectedItem) else{return};let b=captureSnapshot();layer.borderPosition=p;finishMutation(before:b,actionName:"枠線位置変更");refreshAll();NSLog("[Baram Motion] Border position changed: %@",p.displayName) }
    @objc func textHorizontalAlignmentChanged(_ sender:NSPopUpButton){guard let layer=selectedLayer,let a=TextHorizontalAlignment(rawValue:sender.indexOfSelectedItem) else{return};let b=captureSnapshot();layer.textHorizontalAlignment=a;finishMutation(before:b,actionName:"テキスト横位置変更");refreshAll();NSLog("[Baram Motion] Text horizontal alignment changed: %@",a.displayName)}
    @objc func textVerticalAlignmentChanged(_ sender:NSPopUpButton){guard let layer=selectedLayer,let a=TextVerticalAlignment(rawValue:sender.indexOfSelectedItem) else{return};let b=captureSnapshot();layer.textVerticalAlignment=a;finishMutation(before:b,actionName:"テキスト縦位置変更");refreshAll();NSLog("[Baram Motion] Text vertical alignment changed: %@",a.displayName)}

    @objc
    func fontChanged(_ sender: NSPopUpButton) {
        guard let layer = selectedLayer, layer.kind == .text else {
            NSLog("[Baram Motion] ERROR: Font change requires a text layer.")
            return
        }

        guard let item = sender.selectedItem,
              let fontName = item.representedObject as? String,
              !fontName.isEmpty else {
            NSLog("[Baram Motion] ERROR: Invalid font selection.")
            return
        }

        let before = captureSnapshot()
        let frame = playbackController.currentFrame

        if let index = layer.propertyKeyframes.firstIndex(where: {
            $0.property == .font && $0.frame == frame
        }) {
            layer.propertyKeyframes[index].fontName = fontName
        } else if layer.propertyKeyframes.contains(where: { $0.property == .font }) {
            layer.propertyKeyframes.append(.font(frame, value: fontName))
            normalizeKeyframes(layer)
        } else if frame == 0 {
            layer.fontName = fontName
        } else {
            layer.propertyKeyframes.append(.font(frame, value: fontName))
            normalizeKeyframes(layer)
        }

        finishMutation(before: before, actionName: "フォント変更")
        refreshAll()
        NSLog("[Baram Motion] Font changed: %@ frame=%d", fontName, frame)
    }

    @objc func timelineScaleChanged(_ sender:NSTextField){ guard let n=Double(sender.stringValue),n.isFinite else{return}; timelinePixelsPerSecond=max(20,min(600,CGFloat(n))); timelineContent.timelineScale=timelinePixelsPerSecond; updateTimelineSize(); timelineContent.needsDisplay=true; NSLog("[Baram Motion] Timeline scale changed: %.1f px/s",Double(timelinePixelsPerSecond)) }

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

    func makeNumericField(_ value: CGFloat) -> BaramMotionNumericField {
        let field = BaramMotionNumericField(string: formatNumber(value))

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
