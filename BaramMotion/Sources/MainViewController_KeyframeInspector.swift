import AppKit

extension MainViewController {
    func createKeyframePanelContent() {
        let stack = NSStackView(); stack.orientation  =  .vertical; stack.alignment  =  .leading; stack.spacing  =  10; stack.translatesAutoresizingMaskIntoConstraints  =  false
        leftContentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo:leftContentView.leadingAnchor,constant:16),
            stack.trailingAnchor.constraint(equalTo:leftContentView.trailingAnchor,constant:-16),
            stack.topAnchor.constraint(equalTo:leftContentView.topAnchor,constant:52),
            stack.bottomAnchor.constraint(lessThanOrEqualTo:leftContentView.bottomAnchor,constant:-16)
        ])
        keyframeInspectorStack = stack; rebuildKeyframeInspector()
    }

    func rebuildKeyframeInspector() {
        guard let stack = keyframeInspectorStack else { NSLog("[Baram Motion] ERROR: Keyframe inspector stack is nil."); return }
        stack.arrangedSubviews.forEach{stack.removeArrangedSubview($0);$0.removeFromSuperview()}
        keyframeFrameField = nil; keyframeEasingPopup = nil; keyframeXField = nil; keyframeYField = nil; keyframeWidthField = nil; keyframeHeightField = nil
        guard let layer = selectedLayer else { stack.addArrangedSubview(NSTextField(labelWithString:"レイヤーを選択してください")); return }
        let transform = evaluatedTransform(for:layer,frame:playbackController.currentFrame)
        let title = NSTextField(labelWithString:"Transform キーフレーム"); title.font = NSFont.systemFont(ofSize:13,weight:.semibold); stack.addArrangedSubview(title)

        let frame = NSTextField(string:String(playbackController.currentFrame)); frame.controlSize = .small; frame.alignment = .right; frame.widthAnchor.constraint(equalToConstant:120).isActive = true; frame.target = self; frame.action = #selector(keyframeFrameFieldChanged(_:)); keyframeFrameField = frame; stack.addArrangedSubview(makeInspectorRow(title:"フレーム",control:frame))
        let easing = NSPopUpButton(); easing.addItems(withTitles:KeyframeEasing.allCases.map{$0.rawValue}); easing.selectItem(withTitle:currentKeyframeEasing(for:layer).rawValue); easing.target = self; easing.action = #selector(changeKeyframeEasing(_:)); keyframeEasingPopup = easing; stack.addArrangedSubview(makeInspectorRow(title:"イージング",control:easing))

        let fields = [("X",transform.x),("Y",transform.y),("幅",transform.width),("高さ",transform.height)]
        for (name,value) in fields { let f = makeNumericField(value); f.target = self; f.action = #selector(changeKeyframeValue(_:)); f.identifier = NSUserInterfaceItemIdentifier(name); stack.addArrangedSubview(makeInspectorRow(title:name,control:f)); switch name{case"X":keyframeXField = f;case"Y":keyframeYField = f;case"幅":keyframeWidthField = f;default:keyframeHeightField = f} }
        let has = hasKeyframe(layer); let button = NSButton(title:has ? "◆ キーフレームを削除":"◇ 現在位置にキーフレーム",target:self,action:#selector(toggleKeyframeAtCurrentFrame)); button.bezelStyle = .rounded; stack.addArrangedSubview(button)
        let hint = NSTextField(labelWithString:"キーフレームは位置・サイズをまとめて記録します。\nキーフレーム間はイージングで補間されます。"); hint.font = NSFont.systemFont(ofSize:10); hint.textColor = NSColor.secondaryLabelColor; hint.maximumNumberOfLines = 3; stack.addArrangedSubview(hint)
    }

    func currentKeyframeEasing(for layer:LayerModel)->KeyframeEasing { layer.keyframes.first(where:{$0.frame==playbackController.currentFrame})?.easing ?? .linear }
    func hasKeyframe(_ layer:LayerModel)->Bool { layer.keyframes.contains{$0.frame==playbackController.currentFrame} }

    @objc func keyframeFrameFieldChanged(_ sender:NSTextField) {
        guard let layer = selectedLayer, let index = layer.keyframes.firstIndex(where:{$0.frame==playbackController.currentFrame}), let newFrame = Int(sender.stringValue), newFrame>=0 else { NSLog("[Baram Motion] ERROR: Current frame is not a keyframe or value is invalid."); return }
        guard !layer.keyframes.contains(where:{$0.frame==newFrame && $0.frame != playbackController.currentFrame}) else { NSLog("[Baram Motion] ERROR: Keyframe frame already exists."); rebuildKeyframeInspector(); return }
        let before = captureSnapshot(); layer.keyframes[index].frame = newFrame; layer.keyframes.sort{$0.frame<$1.frame}; finishMutation(before:before,actionName:"キーフレーム時間変更")
    }

    @objc func changeKeyframeEasing(_ sender:NSPopUpButton) {
        guard let layer = selectedLayer, let index = layer.keyframes.firstIndex(where:{$0.frame==playbackController.currentFrame}), let title = sender.titleOfSelectedItem, let easing = KeyframeEasing(rawValue:title) else { NSLog("[Baram Motion] ERROR: No current keyframe."); return }
        let before = captureSnapshot(); layer.keyframes[index].easing = easing; finishMutation(before:before,actionName:"イージング変更")
    }

    @objc func toggleKeyframeAtCurrentFrame() {
        guard let layer = selectedLayer else { return }; let before = captureSnapshot()
        if let index = layer.keyframes.firstIndex(where:{$0.frame==playbackController.currentFrame}) { layer.keyframes.remove(at:index) }
        else { let t = evaluatedTransform(for:layer,frame:playbackController.currentFrame); layer.keyframes.append(TransformKeyframe(frame:playbackController.currentFrame,x:t.x,y:t.y,width:t.width,height:t.height)); layer.keyframes.sort{$0.frame<$1.frame} }
        finishMutation(before:before,actionName:"キーフレーム変更")
    }

    @objc func changeKeyframeValue(_ sender:NSTextField) {
        guard let layer = selectedLayer, let index = layer.keyframes.firstIndex(where:{$0.frame==playbackController.currentFrame}), let number = Double(sender.stringValue), number.isFinite else { NSLog("[Baram Motion] ERROR: Add a keyframe before editing its value."); return }
        let before = captureSnapshot(); let value = CGFloat(number)
        switch sender.identifier?.rawValue { case "X":layer.keyframes[index].x = value; case "Y":layer.keyframes[index].y = value; case "幅":layer.keyframes[index].width = max(1,value); case "高さ":layer.keyframes[index].height = max(1,value); default:return }
        finishMutation(before:before,actionName:"キーフレーム値変更")
    }

    func refreshKeyframeInspector() { rebuildKeyframeInspector() }
}
