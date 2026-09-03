import AppKit
import SwiftUI
import Combine

final class LayerListButton:
    NSButton {

    var layerID:
        UUID?
}

// MARK: - Playback / SwiftUI Controls

final class PlaybackController: ObservableObject {

    @Published private(set) var currentFrame: Int = 0
    @Published private(set) var totalFrames: Int = 1
    @Published private(set) var isPlaying: Bool = false

    private var timer: Timer?
    private let frameInterval: TimeInterval = 1.0 / 30.0

    deinit {
        stop()
        NSLog("[Baram Motion] PlaybackController deinitialized.")
    }

    func setTotalFrames(_ value: Int) {
        totalFrames = max(1, value)
        currentFrame = min(currentFrame, totalFrames)
    }

    func setCurrentFrame(_ value: Int, notify: Bool = true) {
        let clamped = max(0, min(totalFrames, value))
        if currentFrame == clamped {
            return
        }
        currentFrame = clamped
    }

    func step(by delta: Int) {
        setCurrentFrame(currentFrame + delta)
        NSLog("[Baram Motion] Playback step: %d", currentFrame)
    }

    func togglePlay() {
        isPlaying ? stop() : start()
    }

    private func start() {
        guard !isPlaying else { return }

        if currentFrame >= totalFrames {
            currentFrame = 0
        }

        isPlaying = true

        timer =
            Timer.scheduledTimer(
                withTimeInterval: frameInterval,
                repeats: true
            ) { [weak self] _ in

                guard let self else { return }

                if currentFrame >= totalFrames {
                    stop()
                    return
                }

                currentFrame += 1
            }

        NSLog("[Baram Motion] Playback started.")
    }

    func stop() {
        timer?.invalidate()
        timer = nil

        if isPlaying {
            isPlaying = false
            NSLog("[Baram Motion] Playback stopped.")
        }
    }
}

struct PlaybackControlsView: View {

    @ObservedObject var controller: PlaybackController
    let onCurrentFrameChanged: (Int) -> Void

    private var timeText: String {
        String(
            format: "%.2fs",
            Double(controller.currentFrame) / 30.0
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("フレーム \(controller.currentFrame) / \(controller.totalFrames)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))

                Spacer()

                Button {
                    controller.step(by: -1)
                    onCurrentFrameChanged(controller.currentFrame)
                } label: {
                    Image(systemName: "chevron.left.2")
                }
                .buttonStyle(.borderless)
                .help("1フレーム戻る")

                Button {
                    controller.togglePlay()
                    onCurrentFrameChanged(controller.currentFrame)
                } label: {
                    Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help(controller.isPlaying ? "停止" : "再生")

                Button {
                    controller.step(by: 1)
                    onCurrentFrameChanged(controller.currentFrame)
                } label: {
                    Image(systemName: "chevron.right.2")
                }
                .buttonStyle(.borderless)
                .help("1フレーム進む")
            }

            Slider(
                value: Binding<Double>(
                    get: { Double(controller.currentFrame) },
                    set: { value in
                        let frame = Int(value.rounded())
                        controller.setCurrentFrame(frame)
                        onCurrentFrameChanged(frame)
                    }
                ),
                in: 0...Double(max(1, controller.totalFrames)),
                step: 1
            )
            .controlSize(.small)

            HStack {
                Text(timeText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("30 fps")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: controller.currentFrame) { _, value in
            onCurrentFrameChanged(value)
        }
    }
}

final class SwitchBindingBox {

    var isOn: Bool

    init(isOn: Bool) {
        self.isOn = isOn
    }
}

struct NativeSwitchEditor: View {

    private let state: SwitchBindingBox
    private let onChanged: (Bool) -> Void

    init(isOn: Bool, onChanged: @escaping (Bool) -> Void) {
        self.state = SwitchBindingBox(isOn: isOn)
        self.onChanged = onChanged
    }

    var body: some View {
        Toggle(
            "",
            isOn: Binding(
                get: { state.isOn },
                set: { value in
                    state.isOn = value
                    onChanged(value)
                    NSLog(
                        "[Baram Motion] Native SwiftUI Toggle changed: %@",
                        value ? "ON" : "OFF"
                    )
                }
            )
        )
        .toggleStyle(.switch)
        .labelsHidden()
        .frame(width: 44, height: 24)
    }
}
