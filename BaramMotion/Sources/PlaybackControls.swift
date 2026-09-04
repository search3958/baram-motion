import AppKit
import SwiftUI

final class PlaybackController: ObservableObject {
    @Published private(set) var currentFrame:Int=0
    var onFrameAdvanced: ((Int) -> Void)?
    @Published private(set) var totalFrames:Int=1
    @Published private(set) var isPlaying:Bool=false
    private var timer:Timer?
    private let frameInterval=1.0/30.0
    deinit { stop() }
    func setTotalFrames(_ value:Int){ totalFrames=max(1,value); currentFrame=min(currentFrame,totalFrames) }
    func setCurrentFrame(_ value:Int,notify:Bool=true){ currentFrame=max(0,min(totalFrames,value)) }
    func step(by delta:Int){setCurrentFrame(currentFrame+delta); NSLog("[Baram Motion] Playback step: %d",currentFrame)}
    func togglePlay(){isPlaying ? stop():start()}
    private func start(){ guard !isPlaying else{return}; if currentFrame>=totalFrames{currentFrame=0}; isPlaying=true; onFrameAdvanced?(currentFrame); timer=Timer.scheduledTimer(withTimeInterval:frameInterval,repeats:true){[weak self] _ in guard let self else{return}; if currentFrame>=totalFrames{stop()}else{currentFrame += 1; onFrameAdvanced?(currentFrame)}} }
    func stop(){timer?.invalidate();timer=nil;isPlaying=false}
}

struct PlaybackControlsView: View {
    @ObservedObject var controller:PlaybackController
    let onCurrentFrameChanged:(Int)->Void
    private var timeText:String {String(format:"%.2fs",Double(controller.currentFrame)/30)}
    var body:some View{
        VStack(alignment:.leading,spacing:8){
            HStack{Text("フレーム \(controller.currentFrame) / \(controller.totalFrames)").font(.system(size:11,weight:.semibold,design:.monospaced));Spacer()
                Button(action:{controller.step(by:-1);onCurrentFrameChanged(controller.currentFrame)}){Image(systemName:"chevron.left.2")}.buttonStyle(.borderless)
                Button(action:{controller.togglePlay();onCurrentFrameChanged(controller.currentFrame)}){Image(systemName:controller.isPlaying ? "pause.fill":"play.fill")}.buttonStyle(.borderedProminent).controlSize(.small)
                Button(action:{controller.step(by:1);onCurrentFrameChanged(controller.currentFrame)}){Image(systemName:"chevron.right.2")}.buttonStyle(.borderless)
            }
            Slider(value:Binding<Double>(get:{Double(controller.currentFrame)},set:{let f=Int($0.rounded());controller.setCurrentFrame(f);onCurrentFrameChanged(f)}),in:0...Double(max(1,controller.totalFrames)),step:1).controlSize(.small)
            HStack{Text(timeText).font(.system(size:10,design:.monospaced)).foregroundStyle(.secondary);Spacer();Text("30 fps").font(.system(size:10,design:.monospaced)).foregroundStyle(.tertiary)}
        }.frame(maxWidth:.infinity,alignment:.leading).onChange(of:controller.currentFrame){_,v in onCurrentFrameChanged(v)}
    }
}

final class LayerListButton:NSButton { var layerID:UUID? }
