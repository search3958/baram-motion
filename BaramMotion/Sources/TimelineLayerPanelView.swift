import AppKit

protocol TimelineLayerPanelViewDelegate: AnyObject {
    func timelineLayerPanel(_ view: TimelineLayerPanelView, didSelectLayer id: UUID)
    func timelineLayerPanel(_ view: TimelineLayerPanelView, didToggleVisibility id: UUID)
    func timelineLayerPanel(_ view: TimelineLayerPanelView, didBeginMovingLayer id: UUID)
    func timelineLayerPanel(_ view: TimelineLayerPanelView, didMoveLayer id: UUID, toIndex index: Int)
    func timelineLayerPanel(_ view: TimelineLayerPanelView, didFinishMovingLayer id: UUID)
}

final class TimelineLayerPanelView: NSView {
    weak var delegate: TimelineLayerPanelViewDelegate?
    private var layers:[MainViewController.LayerModelProxy]=[]
    private var selectedLayerID:UUID?
    var verticalOffset:CGFloat=0 { didSet { needsDisplay=true } }
    var documentHeight:CGFloat=0 { didSet { needsDisplay=true } }
    private let rulerHeight:CGFloat=28
    private let rowHeight:CGFloat=34
    private var draggingID:UUID?

    func reload(layers:[MainViewController.LayerModelProxy], selectedLayerID:UUID?) { self.layers=layers; self.selectedLayerID=selectedLayerID; needsDisplay=true }

    override func draw(_ dirtyRect:NSRect) {
        super.draw(dirtyRect)
        NSColor.controlBackgroundColor.setFill(); bounds.fill()
        let sourceHeight = documentHeight > 0 ? documentHeight : bounds.height
        let firstY=sourceHeight-rulerHeight-rowHeight-verticalOffset
        NSColor.separatorColor.setStroke(); NSRect(x:bounds.width-1,y:0,width:1,height:bounds.height).fill()
        NSString(string:"レイヤー").draw(at:NSPoint(x:12,y:bounds.height-rulerHeight+8),withAttributes:[.font:NSFont.systemFont(ofSize:10,weight:.semibold),.foregroundColor:NSColor.secondaryLabelColor])
        for index in layers.indices {
            let l=layers[index]; let y=firstY-CGFloat(index)*rowHeight
            guard y+rowHeight >= 0 && y <= bounds.height else { continue }
            if l.id==selectedLayerID { NSColor.selectedContentBackgroundColor.withAlphaComponent(0.25).setFill(); NSRect(x:0,y:y,width:bounds.width-1,height:rowHeight).fill() }
            let eyeRect=NSRect(x:8,y:y+8,width:18,height:18)
            let image=NSImage(systemSymbolName:l.isVisible ? "eye.fill":"eye.slash",accessibilityDescription:l.isVisible ? "表示":"非表示")
            image?.isTemplate=true; image?.draw(in:eyeRect)
            let iconText:NSString
            switch l.kindDisplayName { case "Text": iconText="T"; case "Rectangle": iconText="▰"; default: iconText="⌽" }
            iconText.draw(at:NSPoint(x:32,y:y+9),withAttributes:[.font:NSFont.systemFont(ofSize:11,weight:.semibold),.foregroundColor:NSColor.secondaryLabelColor])
            NSString(string:l.name).draw(in:NSRect(x:50,y:y+7,width:bounds.width-58,height:20),withAttributes:[.font:NSFont.systemFont(ofSize:11,weight:l.id==selectedLayerID ? .semibold:.regular),.foregroundColor:NSColor.labelColor])
        }
    }

    override func mouseDown(with event:NSEvent) {
        let p=convert(event.locationInWindow,from:nil)
        guard let index=hitIndex(y:p.y) else{return}
        let l=layers[index]
        if p.x <= 30 { delegate?.timelineLayerPanel(self,didToggleVisibility:l.id); return }
        draggingID=l.id; delegate?.timelineLayerPanel(self,didSelectLayer:l.id); delegate?.timelineLayerPanel(self,didBeginMovingLayer:l.id)
    }
    override func mouseDragged(with event:NSEvent) {
        guard let id=draggingID else{return}
        let p=convert(event.locationInWindow,from:nil)
        guard let target=hitIndex(y:p.y) else{return}
        delegate?.timelineLayerPanel(self,didMoveLayer:id,toIndex:target)
    }
    override func mouseUp(with event:NSEvent) {
        if let id=draggingID { delegate?.timelineLayerPanel(self,didFinishMovingLayer:id) }
        draggingID=nil
    }

    private func hitIndex(y:CGFloat)->Int? {
        let localY=y+verticalOffset
        let sourceHeight = documentHeight > 0 ? documentHeight : bounds.height
        let firstY=sourceHeight-rulerHeight-rowHeight
        let raw=(firstY-localY)/rowHeight
        let index=Int(raw.rounded())
        return layers.indices.contains(index) ? index : nil
    }
}
