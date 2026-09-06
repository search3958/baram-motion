import AppKit
import AVFoundation

extension MainViewController {
    @objc func exportMP4() {
        guard let previewView else {
            NSLog("[Baram Motion] ERROR: Preview view unavailable for MP4 export.")
            return
        }
        let frameCount = max(1, totalPlaybackFrames)
        guard frameCount > 0 else {
            NSLog("[Baram Motion] ERROR: MP4 export frame count is invalid.")
            return
        }

        let panel = NSSavePanel()
        panel.title = "MP4を書き出し"
        panel.nameFieldStringValue = "BaramMotion.mp4"
        panel.canCreateDirectories = true
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.mpeg4Movie]
        } else {
            panel.allowedFileTypes = ["mp4"]
        }
        panel.prompt = "書き出し"

        guard panel.runModal() == .OK, let outputURL = panel.url else {
            NSLog("[Baram Motion] MP4 export cancelled.")
            return
        }

        guard !FileManager.default.fileExists(atPath: outputURL.path) || removeExistingExportFile(at: outputURL) else {
            NSLog("[Baram Motion] ERROR: Existing MP4 file could not be replaced.")
            return
        }

        let width = Int(previewView.bounds.width.rounded())
        let height = Int(previewView.bounds.height.rounded())
        guard width > 0, height > 0 else {
            NSLog("[Baram Motion] ERROR: Invalid preview dimensions for MP4 export: %d x %d", width, height)
            return
        }

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: min(max(width * height * 2, 2_500_000), 6_000_000),
                AVVideoMaxKeyFrameIntervalKey: 60,
                AVVideoExpectedSourceFrameRateKey: Int(playbackFrameRate)
            ]
        ]

        do {
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = false
            guard writer.canAdd(input) else {
                NSLog("[Baram Motion] ERROR: AVAssetWriter cannot add video input.")
                return
            }
            writer.add(input)

            let attributes: [String: Any] = [
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ]
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)

            let originalFrame = playbackController.currentFrame
            let oldLabelHidden = previewResolutionLabel?.isHidden ?? true
            previewResolutionLabel?.isHidden = true
            previewElementViews.values.forEach { $0.updateAppearance(selected: false) }

            guard writer.startWriting() else {
                NSLog("[Baram Motion] ERROR: AVAssetWriter failed to start: %@", writer.error?.localizedDescription ?? "unknown error")
                previewResolutionLabel?.isHidden = oldLabelHidden
                refreshSelectionAppearance()
                return
            }
            writer.startSession(atSourceTime: .zero)

            NSLog("[Baram Motion] MP4 export started: %d frames, %d x %d", frameCount, width, height)
            var exportSucceeded = true

            for frame in 0..<frameCount {
                if !input.isReadyForMoreMediaData {
                    let deadline = Date().addingTimeInterval(0.25)
                    while !input.isReadyForMoreMediaData && Date() < deadline {
                        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
                    }
                }
                guard input.isReadyForMoreMediaData else {
                    NSLog("[Baram Motion] ERROR: Video input did not become ready at frame %d.", frame)
                    exportSucceeded = false
                    break
                }

                playbackController.setCurrentFrame(frame, notify: false)
                refreshPreview()
                previewView.layoutSubtreeIfNeeded()
                previewView.displayIfNeeded()
                previewElementViews.values.forEach {
                    $0.layoutSubtreeIfNeeded()
                    $0.applyFrameForExportIfNeeded()
                    $0.displayIfNeeded()
                }

                guard let pixelBuffer = makeExportPixelBuffer(from: previewView, width: width, height: height) else {
                    NSLog("[Baram Motion] ERROR: Failed to create pixel buffer at frame %d.", frame)
                    exportSucceeded = false
                    break
                }

                let presentationTime = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(playbackFrameRate))
                guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                    NSLog("[Baram Motion] ERROR: Failed to append MP4 frame %d: %@", frame, writer.error?.localizedDescription ?? "unknown error")
                    exportSucceeded = false
                    break
                }
                if frame == 0 || frame == frameCount - 1 || frame % max(1, Int(playbackFrameRate)) == 0 {
                    NSLog("[Baram Motion] MP4 export progress: %d/%d", frame + 1, frameCount)
                }
            }

            if exportSucceeded {
                input.markAsFinished()
            } else {
                input.markAsFinished()
                writer.cancelWriting()
            }
            let finalExportSucceeded = exportSucceeded
            writer.finishWriting { [weak self, finalExportSucceeded] in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.playbackController.setCurrentFrame(originalFrame, notify: false)
                    self.previewResolutionLabel?.isHidden = oldLabelHidden
                    self.refreshAll()
                    if finalExportSucceeded && writer.status == .completed {
                        NSLog("[Baram Motion] MP4 export succeeded: %@", outputURL.path)
                    } else {
                        NSLog("[Baram Motion] ERROR: MP4 export failed: %@", writer.error?.localizedDescription ?? "unknown error")
                        if FileManager.default.fileExists(atPath: outputURL.path) {
                            try? FileManager.default.removeItem(at: outputURL)
                            NSLog("[Baram Motion] Incomplete MP4 removed: %@", outputURL.path)
                        }
                    }
                }
            }
        } catch {
            NSLog("[Baram Motion] ERROR: Could not create MP4 writer: %@", error.localizedDescription)
        }
    }

    private func makeExportPixelBuffer(from view: NSView, width: Int, height: Int) -> CVPixelBuffer? {
        guard let pngData = makeRenderedPNGData(from: view) else {
            NSLog("[Baram Motion] ERROR: Failed to render preview frame before MP4 encoding.")
            return nil
        }
        guard let image = NSImage(data: pngData) else {
            NSLog("[Baram Motion] ERROR: Rendered PNG could not be decoded.")
            return nil
        }
        guard let pixelBuffer = makePixelBuffer(width: width, height: height) else {
            return nil
        }

        guard CVPixelBufferLockBaseAddress(pixelBuffer, []) == kCVReturnSuccess else {
            NSLog("[Baram Motion] ERROR: CVPixelBufferLockBaseAddress failed.")
            return nil
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            NSLog("[Baram Motion] ERROR: Pixel buffer base address is nil.")
            return nil
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            NSLog("[Baram Motion] ERROR: Could not create MP4 pixel-buffer graphics context.")
            return nil
        }

        context.setFillColor(BaramMotionTheme.previewBackground.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            NSLog("[Baram Motion] ERROR: Rendered PNG has no CGImage.")
            return nil
        }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }

    private func makePixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ] as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            NSLog("[Baram Motion] ERROR: CVPixelBufferCreate failed: %d", status)
            return nil
        }
        return pixelBuffer
    }

    private func makeRenderedPNGData(from view: NSView) -> Data? {
        guard view.bounds.width > 0, view.bounds.height > 0 else {
            NSLog("[Baram Motion] ERROR: Preview bounds are empty during frame rendering.")
            return nil
        }

        // Render exactly one frame using the same AppKit view hierarchy used by
        // the editor. This keeps all layers composited together. PDF rendering is
        // used as the primary capture path because it recursively captures
        // layer-backed NSViews and NSHostingView content more reliably than
        // CALayer.render(in:) for this editor.
        let pdfData = view.dataWithPDF(inside: view.bounds)
        if !pdfData.isEmpty,
           let provider = CGDataProvider(data: pdfData as CFData),
           let document = CGPDFDocument(provider),
           let page = document.page(at: 1) {
            let box = page.getBoxRect(.mediaBox)
            let width = max(1, Int(view.bounds.width.rounded()))
            let height = max(1, Int(view.bounds.height.rounded()))
            guard let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width,
                pixelsHigh: height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bitmapFormat: [],
                bytesPerRow: 0,
                bitsPerPixel: 0
            ), let graphics = NSGraphicsContext(bitmapImageRep: rep) else {
                NSLog("[Baram Motion] ERROR: Could not allocate PDF frame bitmap.")
                return nil
            }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphics
            graphics.cgContext.setFillColor(BaramMotionTheme.previewBackground.cgColor)
            graphics.cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
            let scale = min(CGFloat(width) / max(1, box.width), CGFloat(height) / max(1, box.height))
            let drawWidth = box.width * scale
            let drawHeight = box.height * scale
            let drawRect = CGRect(x: (CGFloat(width) - drawWidth) * 0.5, y: (CGFloat(height) - drawHeight) * 0.5, width: drawWidth, height: drawHeight)
            graphics.cgContext.saveGState()
            graphics.cgContext.translateBy(x: drawRect.minX, y: drawRect.minY + drawRect.height)
            graphics.cgContext.scaleBy(x: scale, y: -scale)
            graphics.cgContext.translateBy(x: -box.minX, y: -box.minY)
            graphics.cgContext.drawPDFPage(page)
            graphics.cgContext.restoreGState()
            graphics.flushGraphics()
            NSGraphicsContext.restoreGraphicsState()
            if let data = rep.representation(using: .png, properties: [:]) {
                NSLog("[Baram Motion] PNG-style frame render succeeded via PDF, %.0f x %.0f", view.bounds.width, view.bounds.height)
                return data
            }
        }

        // Fallback for unusual AppKit configurations.
        guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            NSLog("[Baram Motion] ERROR: Could not create fallback bitmap representation.")
            return nil
        }
        view.cacheDisplay(in: view.bounds, to: representation)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            NSLog("[Baram Motion] ERROR: Fallback PNG encoding failed.")
            return nil
        }
        NSLog("[Baram Motion] PNG-style frame render succeeded via AppKit cache fallback.")
        return data
    }

    private func removeExistingExportFile(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            NSLog("[Baram Motion] Existing export file removed: %@", url.path)
            return true
        } catch {
            NSLog("[Baram Motion] ERROR: Could not remove existing export file: %@", error.localizedDescription)
            return false
        }
    }
}
