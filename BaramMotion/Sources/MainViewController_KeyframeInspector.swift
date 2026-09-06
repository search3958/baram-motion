import AppKit

extension MainViewController {
    func createKeyframePanelContent() {
        guard leftContentView != nil else { NSLog("[Baram Motion] ERROR: Graph editor container unavailable."); return }
        let graph = KeyframeGraphView(); graph.translatesAutoresizingMaskIntoConstraints = false; graph.delegate = self
        leftContentView.addSubview(graph)
        NSLayoutConstraint.activate([
            graph.leadingAnchor.constraint(equalTo: leftContentView.leadingAnchor, constant: 10),
            graph.trailingAnchor.constraint(equalTo: leftContentView.trailingAnchor, constant: -10),
            graph.topAnchor.constraint(equalTo: leftContentView.topAnchor, constant: 40),
            graph.bottomAnchor.constraint(equalTo: leftContentView.bottomAnchor, constant: -10)
        ])
        keyframeGraphView = graph
        refreshKeyframeInspector()
        NSLog("[Baram Motion] Unified graph editor initialized.")
    }

    func refreshKeyframeInspector() {
        guard let graph = keyframeGraphView else { return }
        graph.layers = layers
        graph.selectedLayerID = selectedLayerID
        graph.currentFrame = playbackController.currentFrame
        graph.selectedProperty = selectedGraphProperty
        graph.selectedKeyframeFrame = selectedGraphFrame
    }

    func keyframeFor(property: AnimatedProperty, layer: LayerModel, frame: Int) -> Bool {
        layer.propertyKeyframes.contains { $0.frame == frame && $0.property == property }
    }

    @objc func toggleKeyframeForProperty(_ sender: NSButton) {
        guard let layer = selectedLayer, let raw = sender.identifier?.rawValue, let property = AnimatedProperty(rawValue: raw) else {
            NSLog("[Baram Motion] ERROR: Invalid keyframe property button target."); return
        }
        let before = captureSnapshot(); toggleKeyframe(property: property, layer: layer, frame: playbackController.currentFrame)
        selectedGraphProperty = property; selectedGraphFrame = playbackController.currentFrame
        finishMutation(before: before, actionName: "\(property.rawValue) キーフレーム変更")
    }

    func toggleKeyframe(property: AnimatedProperty, layer: LayerModel, frame: Int) {
        if let idx = layer.propertyKeyframes.firstIndex(where: { $0.frame == frame && $0.property == property }) { layer.propertyKeyframes.remove(at: idx); return }
        switch property {
        case .x, .y, .width, .height, .scaleX, .scaleY, .rotation, .opacity, .borderWidth:
            let t = evaluatedTransform(for: layer, frame: frame)
            let value: CGFloat
            switch property {
            case .x: value = t.x
            case .y: value = t.y
            case .width: value = t.width
            case .height: value = t.height
            case .scaleX: value = t.scaleX
            case .scaleY: value = t.scaleY
            case .rotation: value = t.rotation
            case .opacity: value = evaluatedOpacity(for: layer, frame: frame)
            case .borderWidth: value = layer.borderWidth
            default: value = 0
            }
            layer.propertyKeyframes.append(.scalar(property, frame: frame, value: value))
        case .cornerRadius:
            layer.propertyKeyframes.append(.scalar(.cornerRadius, frame: frame, value: evaluatedCornerRadius(for: layer, frame: frame)))
        case .borderColor:
            layer.propertyKeyframes.append(PropertyKeyframe(frame: frame, property: .borderColor, scalar: 0, text: "", fontName: "", boolValue: false, colorValue: ColorValue.from(layer.borderColor), easing: .easeInOut))
        case .color:
            layer.propertyKeyframes.append(.color(frame, value: ColorValue.from(evaluatedColor(for: layer, frame: frame))))
        case .text:
            layer.propertyKeyframes.append(.text(frame, value: evaluatedText(for: layer, frame: frame)))
        case .font:
            layer.propertyKeyframes.append(.font(frame, value: evaluatedFontName(for: layer, frame: frame)))
        case .isOn:
            layer.propertyKeyframes.append(.state(frame, value: evaluatedSwitchState(for: layer, frame: frame)))
        }
        normalizeKeyframes(layer)
    }

    func normalizeKeyframes(_ layer: LayerModel) {
        layer.propertyKeyframes.sort { $0.frame == $1.frame ? $0.property.rawValue < $1.property.rawValue : $0.frame < $1.frame }
    }

    func moveGraphKeyframe(layerID: UUID, property: AnimatedProperty, fromFrame: Int, toFrame: Int, value: CGFloat?) {
        guard let layer = layers.first(where: { $0.id == layerID }), let idx = layer.propertyKeyframes.firstIndex(where: { $0.property == property && $0.frame == fromFrame }) else { return }
        let target = max(0, min(totalPlaybackFrames, toFrame))
        guard !layer.propertyKeyframes.contains(where: { $0.property == property && $0.frame == target && $0.frame != fromFrame }) else { return }
        layer.propertyKeyframes[idx].frame = target
        if let value {
            switch property {
            case .x,.y: layer.propertyKeyframes[idx].scalar = value
            case .width,.height: layer.propertyKeyframes[idx].scalar = max(1, value)
            case .scaleX,.scaleY: layer.propertyKeyframes[idx].scalar = max(0.001, value)
            case .rotation: layer.propertyKeyframes[idx].scalar = value
            case .opacity: layer.propertyKeyframes[idx].scalar = max(0, min(1, value))
            case .borderWidth: layer.propertyKeyframes[idx].scalar = max(0, value)
            case .cornerRadius: layer.propertyKeyframes[idx].scalar = max(0, value)
            case .borderColor: break
            case .color:
                let old = layer.propertyKeyframes[idx].colorValue ?? ColorValue.from(layer.color)
                let brightness = max(0, min(1, value))
                let current = old.brightness
                let factor = current > 0.0001 ? brightness/current : brightness
                layer.propertyKeyframes[idx].colorValue = ColorValue(r: min(1,old.r*factor), g:min(1,old.g*factor), b:min(1,old.b*factor), a:old.a)
                layer.propertyKeyframes[idx].scalar = brightness
            case .isOn: layer.propertyKeyframes[idx].boolValue = value >= 0.5
            case .text, .font: break
            }
        }
        normalizeKeyframes(layer); selectedGraphProperty=property; selectedGraphFrame=target; playbackFrameChanged(target)
    }
}

extension MainViewController: KeyframeGraphViewDelegate {
    func keyframeGraph(_ graph: KeyframeGraphView, didSelect property: AnimatedProperty, frame: Int) {
        selectedGraphProperty=property; selectedGraphFrame=frame; playbackFrameChanged(frame)
    }

    func keyframeGraph(_ graph: KeyframeGraphView, didMove layerID: UUID, property: AnimatedProperty, fromFrame: Int, toFrame: Int, value: CGFloat?) {
        moveGraphKeyframe(layerID: layerID, property: property, fromFrame: fromFrame, toFrame: toFrame, value: value); refreshAll()
    }

    func keyframeGraph(_ graph: KeyframeGraphView, didChangeEasingAt layerID: UUID, property: AnimatedProperty, frame: Int, easing: CubicBezier) {
        guard let layer=layers.first(where:{$0.id==layerID}), let idx=layer.propertyKeyframes.firstIndex(where:{$0.frame==frame && $0.property==property}) else { return }
        let before=captureSnapshot(); layer.propertyKeyframes[idx].easing=easing; finishMutation(before:before, actionName:"グラフのイージング変更"); refreshKeyframeInspector()
    }

    func keyframeGraph(_ graph: KeyframeGraphView, didDeleteKeyframeAt layerID: UUID, property: AnimatedProperty, frame: Int) {
        guard let layer = layers.first(where: { $0.id == layerID }) else { return }
        guard let idx = layer.propertyKeyframes.firstIndex(where: { $0.property == property && $0.frame == frame }) else { return }
        let before = captureSnapshot()
        layer.propertyKeyframes.remove(at: idx)
        normalizeKeyframes(layer)
        finishMutation(before: before, actionName: "キーフレーム削除")
        refreshAll()
    }

    func keyframeGraph(_ graph: KeyframeGraphView, didAddKeyframeFor property: AnimatedProperty, at frame: Int) {
        guard let layer=selectedLayer else { return }
        let before=captureSnapshot(); toggleKeyframe(property:property, layer:layer, frame:frame); selectedGraphProperty=property; selectedGraphFrame=frame; playbackFrameChanged(frame); finishMutation(before:before,actionName:"グラフからキーフレーム追加"); refreshAll()
    }
}
