import AppKit
import UniformTypeIdentifiers

extension MainViewController {
    @objc func exportCurrentFrame() {
        guard let previewView else { NSLog("[Baram Motion] ERROR: Preview view unavailable for export."); return }
        let alert = NSAlert(); alert.messageText = "現在のフレームを書き出し"; alert.informativeText = "出力サイズと形式を選択してください。"
        let sizePopup = NSPopUpButton(); sizePopup.addItems(withTitles:["1920 × 1080","1280 × 720","960 × 540","3840 × 2160"])
        let formatPopup = NSPopUpButton(); formatPopup.addItems(withTitles:["PNG","JPEG"])
        let stack = NSStackView(views:[NSTextField(labelWithString:"出力サイズ"),sizePopup,NSTextField(labelWithString:"形式"),formatPopup]); stack.orientation = .vertical; stack.spacing = 8
        alert.accessoryView = stack; alert.addButton(withTitle:"フォルダを選択"); alert.addButton(withTitle:"キャンセル")
        guard alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn else { NSLog("[Baram Motion] Export cancelled."); return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false; panel.prompt = "書き出し"
        guard panel.runModal() == NSApplication.ModalResponse.OK, let folder = panel.url else { NSLog("[Baram Motion] Export folder not selected."); return }
        let sizes = [(1920,1080),(1280,720),(960,540),(3840,2160)]; let size = sizes[min(max(sizePopup.indexOfSelectedItem,0),sizes.count-1)]
        let isJPEG = formatPopup.indexOfSelectedItem == 1
        let repWidth = size.0, repHeight = size.1
        // Hide editor-only overlay while capturing, then restore immediately.
        let oldLabelHidden = previewResolutionLabel?.isHidden ?? true; previewResolutionLabel?.isHidden = true
        previewElementViews.values.forEach{$0.updateAppearance(selected:false)}
        guard let source = previewView.bitmapImageRepForCachingDisplay(in:previewView.bounds) else { NSLog("[Baram Motion] ERROR: Could not create bitmap representation."); previewResolutionLabel?.isHidden = oldLabelHidden; refreshSelectionAppearance(); return }
        previewView.cacheDisplay(in:previewView.bounds,to:source)
        previewResolutionLabel?.isHidden = oldLabelHidden; refreshSelectionAppearance()
        guard let image = NSImage(size:previewView.bounds.size) as NSImage? else { NSLog("[Baram Motion] ERROR: Could not create source image."); return }
        image.addRepresentation(source)
        guard let dest = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:repWidth,pixelsHigh:repHeight,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bitmapFormat:[],bytesPerRow:0,bitsPerPixel:0) else { NSLog("[Baram Motion] ERROR: Could not allocate output bitmap."); return }
        guard let ctx = NSGraphicsContext(bitmapImageRep:dest) else { NSLog("[Baram Motion] ERROR: Could not create output graphics context."); return }
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ctx; image.draw(in:NSRect(x:0,y:0,width:repWidth,height:repHeight),from:NSRect(origin:.zero,size:image.size),operation:.copy,fraction:1); ctx.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
        let type: NSBitmapImageRep.FileType  =  isJPEG ? .jpeg : .png
        let data = dest.representation(using:type,properties:isJPEG ? [.compressionFactor:0.92] : [:])
        guard let data else { NSLog("[Baram Motion] ERROR: Image encoding failed."); return }
        let ext = isJPEG ? "jpg":"png"
        let file = folder.appendingPathComponent(String(format:"BaramMotion_%05d.%@",playbackController.currentFrame,ext))
        do { try data.write(to:file); NSLog("[Baram Motion] Export succeeded: %@",file.path) }
        catch { NSLog("[Baram Motion] ERROR: Export failed: %@",error.localizedDescription) }
    }
}
