import AppKit

protocol TimelineContentViewDelegate: AnyObject {
    func timelineContentView(_ view: TimelineContentView, didSelectLayer id: UUID)
    func timelineContentView(_ view: TimelineContentView, didBeginEditingLayer id: UUID)
    func timelineContentView(_ view: TimelineContentView, didChangeLayer id: UUID, startTime: CGFloat, duration: CGFloat)
    func timelineContentView(_ view: TimelineContentView, didFinishEditingLayer id: UUID)
    func timelineContentView(_ view: TimelineContentView, didRequestFrame frame: Int)
    func timelineContentView(_ view: TimelineContentView, didRequestAddKeyframe layerID: UUID, frame: Int)
}

final class TimelineContentView: NSView {
    weak var delegate: TimelineContentViewDelegate?
    private var layers:[MainViewController.LayerModelProxy] = []
    private var selectedLayerID:UUID?
    private let rulerHeight:CGFloat = 28
    private let rowHeight:CGFloat = 34
    var timelineScale:CGFloat = 90 { didSet { timelineScale = max(20, min(600, timelineScale)); needsDisplay=true; resetCursorRects() } }
    var frameRate: CGFloat = 30 { didSet { frameRate = max(1, frameRate); needsDisplay=true; resetCursorRects() } }
    private let edgeHitWidth:CGFloat = 8
    private var minimumDuration: CGFloat { 1.0 / max(1, frameRate) }
    private var scrubbingPlayhead = false
    private enum Interaction { case none, move, resizeLeft, resizeRight }
    private var interaction:Interaction  =  .none
    private var activeLayerID:UUID?
    private var dragStartMouseX:CGFloat = 0
    private var dragStartMouseY:CGFloat = 0
    private var originalStartTime:CGFloat = 0
    private var originalDuration:CGFloat = 0
    var currentFrame:Int = 0 { didSet { needsDisplay = true; updateTrackingAreas() } }

    override var isFlipped:Bool { false }

    func reload(layers:[MainViewController.LayerModelProxy], selectedLayerID:UUID?) {
        self.layers = layers; self.selectedLayerID = selectedLayerID; needsDisplay = true; resetCursorRects()
    }

    private var contentHeight:CGFloat { bounds.height }

    override func draw(_ dirtyRect:NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { NSLog("[Baram Motion] ERROR: Timeline graphics context is nil."); return }
        NSColor.controlBackgroundColor.setFill(); bounds.fill()
        drawRuler(ctx); drawRows(ctx); drawPlayhead(ctx)
    }

    private func drawRuler(_ ctx:CGContext) {
        let top = contentHeight-rulerHeight
        NSColor.underPageBackgroundColor.setFill(); NSRect(x:0,y:top,width:bounds.width,height:rulerHeight).fill()
        var second:CGFloat = 0
        while second*timelineScale < bounds.width {
            let x = second*timelineScale; let major = Int(second)%5==0
            NSColor.separatorColor.setStroke(); ctx.setLineWidth(1)
            ctx.move(to:CGPoint(x:x,y:top)); ctx.addLine(to:CGPoint(x:x,y:top+(major ? 14:8))); ctx.strokePath()
            if major { NSString(string:String(format:"%.0fs",Double(second))).draw(at:NSPoint(x:x+4,y:top+8),withAttributes:[.font:NSFont.monospacedSystemFont(ofSize:10,weight:.regular),.foregroundColor:NSColor.secondaryLabelColor]) }
            second += 1
        }
    }

    private func drawRows(_ ctx:CGContext) {
        let firstRowY = contentHeight-rulerHeight-rowHeight
        for index in layers.indices {
            let layer = layers[index]
            let y = firstRowY-CGFloat(index)*rowHeight
            let rowColor  =  index % 2 == 0 ? NSColor.controlBackgroundColor : NSColor.underPageBackgroundColor
            rowColor.setFill()
            NSRect(x:0,y:y,width:bounds.width,height:rowHeight).fill()
            let rect = NSRect(x:layer.startTime*timelineScale,y:y+5,width:max(20,layer.duration*timelineScale),height:rowHeight-10)
            layer.color.withAlphaComponent(layer.id==selectedLayerID ? 0.88:0.66).setFill()
            let path = NSBezierPath(roundedRect:rect,xRadius:6,yRadius:6); path.fill()
            if layer.id==selectedLayerID { NSColor.controlAccentColor.setStroke(); path.lineWidth = 2; path.stroke() }
            NSString(string:layer.name).draw(in:rect.insetBy(dx:10,dy:6),withAttributes:[.font:NSFont.systemFont(ofSize:11,weight:layer.id==selectedLayerID ? .semibold:.medium),.foregroundColor:NSColor.white])
            for frame in layer.keyframeFrames { drawDiamond(atX:CGFloat(frame)/frameRate*timelineScale, centerY:y+rowHeight/2, selected:frame==currentFrame, context:ctx) }
        }
    }

    private func drawDiamond(atX x:CGFloat, centerY:CGFloat, selected:Bool, context:CGContext) {
        let r:CGFloat = 5
        let p = NSBezierPath(); p.move(to:NSPoint(x:x,y:centerY+r)); p.line(to:NSPoint(x:x+r,y:centerY)); p.line(to:NSPoint(x:x,y:centerY-r)); p.line(to:NSPoint(x:x-r,y:centerY)); p.close()
        (selected ? NSColor.controlAccentColor : NSColor.secondaryLabelColor).setFill(); p.fill()
    }

    private func drawPlayhead(_ ctx:CGContext) {
        let x = CGFloat(currentFrame)/max(1, frameRate)*timelineScale
        guard x>=0 && x<=bounds.width else{return}
        NSColor.controlAccentColor.setStroke(); ctx.setLineWidth(2); ctx.move(to:CGPoint(x:x,y:0)); ctx.addLine(to:CGPoint(x:x,y:bounds.height)); ctx.strokePath()
        let knob = NSBezierPath(); knob.move(to:NSPoint(x:x-7,y:0)); knob.line(to:NSPoint(x:x+7,y:0)); knob.line(to:NSPoint(x:x,y:10)); knob.close(); NSColor.controlAccentColor.setFill(); knob.fill()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        for index in layers.indices {
            let rowY = contentHeight-rulerHeight-rowHeight-CGFloat(index)*rowHeight
            let layer = layers[index]
            let rect = NSRect(x:layer.startTime*timelineScale,y:rowY+5,width:max(20,layer.duration*timelineScale),height:rowHeight-10)
            if rect.width>=20 {
                addCursorRect(NSRect(x:rect.minX,y:rect.minY,width:min(edgeHitWidth,rect.width/2),height:rect.height),cursor:.resizeLeftRight)
                addCursorRect(NSRect(x:max(rect.minX+rect.width-edgeHitWidth,rect.minX),y:rect.minY,width:min(edgeHitWidth,rect.width/2),height:rect.height),cursor:.resizeLeftRight)
            }
        }
    }

    override func mouseDown(with event:NSEvent) {
        let p = convert(event.locationInWindow,from:nil)
        if p.y > contentHeight-rulerHeight {
            scrubbingPlayhead = true
            delegate?.timelineContentView(self,didRequestFrame:max(0,Int((p.x/timelineScale*frameRate).rounded())))
            return
        }
        guard let hit = hitTest(at:p) else {
            interaction = .none; activeLayerID = nil; return
        }
        selectedLayerID = hit.layer.id
        delegate?.timelineContentView(self,didSelectLayer:hit.layer.id)
        let localX = p.x-hit.rect.minX
        if hit.rect.width >= 20 && localX <= edgeHitWidth { interaction = .resizeLeft }
        else if hit.rect.width >= 20 && localX >= hit.rect.width-edgeHitWidth { interaction = .resizeRight }
        else { interaction = .move }
        if event.clickCount >= 2 {
            delegate?.timelineContentView(self,didRequestFrame:max(0,Int((p.x/timelineScale*frameRate).rounded())))
            interaction = .none
            return
        }
        activeLayerID = hit.layer.id; dragStartMouseX = p.x; dragStartMouseY = p.y; originalStartTime = hit.layer.startTime; originalDuration = hit.layer.duration
        delegate?.timelineContentView(self,didBeginEditingLayer:hit.layer.id)
    }

    override func mouseDragged(with event:NSEvent) {
        let p = convert(event.locationInWindow,from:nil)
        if scrubbingPlayhead {
            delegate?.timelineContentView(self,didRequestFrame:max(0,Int((p.x/timelineScale*frameRate).rounded())))
            return
        }
        guard interaction != .none, let activeLayerID, let active = layers.first(where:{$0.id==activeLayerID}) else{return}
        let deltaTime = round(((p.x-dragStartMouseX)/timelineScale)*frameRate)/frameRate
        var start = originalStartTime, duration = originalDuration
        switch interaction {
        case .move: start = max(0,originalStartTime+deltaTime)
        case .resizeLeft:
            let newStart = max(0,min(originalStartTime+originalDuration-minimumDuration,originalStartTime+deltaTime)); start = newStart; duration = originalDuration-(newStart-originalStartTime)
        case .resizeRight: duration = max(minimumDuration,originalDuration+deltaTime)
        case .none: return
        }
        delegate?.timelineContentView(self,didChangeLayer:active.id,startTime:start,duration:duration)
    }

    override func mouseUp(with event:NSEvent) {
        if scrubbingPlayhead { scrubbingPlayhead = false; return }
        if let activeLayerID { delegate?.timelineContentView(self,didFinishEditingLayer:activeLayerID) }
        interaction = .none; activeLayerID = nil; resetCursorRects()
    }

    private func hitTest(at point:CGPoint)->(layer:MainViewController.LayerModelProxy,rect:NSRect)? {
        let firstRowY = contentHeight-rulerHeight-rowHeight
        for index in layers.indices {
            let l = layers[index]; let y = firstRowY-CGFloat(index)*rowHeight
            let rect = NSRect(x:l.startTime*timelineScale,y:y+5,width:max(20,l.duration*timelineScale),height:rowHeight-10)
            if rect.contains(point) { return (l,rect) }
        }
        return nil
    }
}
