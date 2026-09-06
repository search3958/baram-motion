import AppKit
import SwiftUI

final class PlaybackController: ObservableObject {
    @Published private(set) var currentFrame:Int=0
    var onFrameAdvanced: ((Int) -> Void)?
    @Published private(set) var totalFrames:Int=1
    @Published private(set) var isPlaying:Bool=false
    private var timer: Timer?
    private var playbackStartTime: CFTimeInterval = 0
    private var playbackStartFrame: Int = 0
    private let frameRate: Double = 30.0
    deinit { stop() }
    var frameDuration: Double { 1.0 / frameRate }
    func setTotalFrames(_ value:Int){ totalFrames=max(1,value); currentFrame=min(currentFrame,totalFrames) }
    func setCurrentFrame(_ value:Int,notify:Bool=true){
        let clamped=max(0,min(totalFrames,value))
        currentFrame=clamped
        if notify { onFrameAdvanced?(currentFrame) }
    }
    func step(by delta:Int){setCurrentFrame(currentFrame+delta); NSLog("[Baram Motion] Playback step: %d (%.4fs)",currentFrame,frameDuration)}
    func togglePlay(){isPlaying ? stop():start()}
    private func start(){
        guard !isPlaying else{return}
        if currentFrame>=totalFrames { currentFrame=0 }
        playbackStartFrame=currentFrame
        playbackStartTime=CACurrentMediaTime()
        isPlaying=true
        onFrameAdvanced?(currentFrame)
        timer=Timer.scheduledTimer(withTimeInterval: frameDuration * 0.5, repeats:true){ [weak self] _ in self?.advanceFromClock() }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        NSLog("[Baram Motion] Playback started: frame=%d frameDuration=%.6fs", currentFrame, frameDuration)
    }
    private func advanceFromClock(){
        guard isPlaying else{return}
        let elapsed=max(0, CACurrentMediaTime()-playbackStartTime)
        let target=playbackStartFrame + Int(floor(elapsed * frameRate + 1e-9))
        if target >= totalFrames { setCurrentFrame(totalFrames); stop(); return }
        if target != currentFrame { setCurrentFrame(target, notify: true) }
    }
    func stop(){
        timer?.invalidate(); timer=nil
        if isPlaying { NSLog("[Baram Motion] Playback stopped at frame=%d time=%.4fs", currentFrame, Double(currentFrame)*frameDuration) }
        isPlaying=false
    }
}

struct PlaybackControlsView: View {
    @ObservedObject var controller:PlaybackController
    let onCurrentFrameChanged:(Int)->Void
    private var timeText:String {String(format:"%.3fs",Double(controller.currentFrame)*controller.frameDuration)}
    var body:some View{
        VStack(alignment:.leading,spacing:8){
            HStack{Text("フレーム \(controller.currentFrame) / \(controller.totalFrames)").font(.system(size:11,weight:.semibold,design:.monospaced));Spacer()
                Button(action:{controller.step(by:-1);onCurrentFrameChanged(controller.currentFrame)}){Image(systemName:"chevron.left.2")}.buttonStyle(.borderless)
                Button(action:{controller.togglePlay();onCurrentFrameChanged(controller.currentFrame)}){Image(systemName:controller.isPlaying ? "pause.fill":"play.fill")}.buttonStyle(.borderedProminent).controlSize(.small)
                Button(action:{controller.step(by:1);onCurrentFrameChanged(controller.currentFrame)}){Image(systemName:"chevron.right.2")}.buttonStyle(.borderless)
            }
            Slider(value:Binding<Double>(get:{Double(controller.currentFrame)},set:{let f=Int($0.rounded());controller.setCurrentFrame(f);onCurrentFrameChanged(f)}),in:0...Double(max(1,controller.totalFrames)),step:1).controlSize(.small)
            HStack{Text(timeText).font(.system(size:10,design:.monospaced)).foregroundStyle(.secondary);Spacer();Text("30 fps · 1F = 0.0333s").font(.system(size:10,design:.monospaced)).foregroundStyle(.tertiary)}
        }.frame(maxWidth:.infinity,alignment:.leading).onChange(of:controller.currentFrame){_,v in onCurrentFrameChanged(v)}
    }
}

final class LayerListButton:NSButton { var layerID:UUID? }
