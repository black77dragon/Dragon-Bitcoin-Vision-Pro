import SwiftUI

@MainActor
struct ReplayTransportBar: View {
    let isPlaying: Bool
    let canInteract: Bool
    let stageLabel: String
    let timestamp: Date
    let speed: ReplayPlaybackSpeed
    let controlSize: ControlSize
    let theme: ReplayTransportBarTheme
    let onTogglePlayback: () -> Void
    let onStopPlayback: () -> Void
    let onChangeSpeed: (ReplayPlaybackSpeed) -> Void

    init(
        isPlaying: Bool,
        canInteract: Bool,
        stageLabel: String,
        timestamp: Date,
        speed: ReplayPlaybackSpeed,
        controlSize: ControlSize = .large,
        theme: ReplayTransportBarTheme,
        onTogglePlayback: @escaping () -> Void,
        onStopPlayback: @escaping () -> Void,
        onChangeSpeed: @escaping (ReplayPlaybackSpeed) -> Void
    ) {
        self.isPlaying = isPlaying
        self.canInteract = canInteract
        self.stageLabel = stageLabel
        self.timestamp = timestamp
        self.speed = speed
        self.controlSize = controlSize
        self.theme = theme
        self.onTogglePlayback = onTogglePlayback
        self.onStopPlayback = onStopPlayback
        self.onChangeSpeed = onChangeSpeed
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(theme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
        )
        .animation(.snappy(duration: 0.22), value: isPlaying)
        .animation(.snappy(duration: 0.22), value: speed)
    }

    private var horizontalLayout: some View {
        HStack(alignment: .center, spacing: 18) {
            transportControls
            speedPicker
            Spacer(minLength: 12)
            statusSummary(alignment: .trailing)
                .frame(minWidth: 132, alignment: .trailing)
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            transportControls
            speedPicker
            statusSummary(alignment: .leading)
        }
    }

    private var transportControls: some View {
        ControlGroup {
            Button(action: onTogglePlayback) {
                Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)

            Button(action: onStopPlayback) {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .tint(theme.secondaryControlTint)
        }
        .buttonBorderShape(.capsule)
        .controlSize(controlSize)
        .disabled(!canInteract)
    }

    private var speedPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Speed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            Picker("Playback speed", selection: speedBinding) {
                ForEach(ReplayPlaybackSpeed.allCases) { speed in
                    Text(speed.label)
                        .tag(speed)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(minWidth: 240)
            .disabled(!canInteract)
        }
    }

    private func statusSummary(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(stageLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
            Text(timestamp, format: .dateTime.hour().minute().second())
                .font(.headline.monospacedDigit())
                .foregroundStyle(theme.primaryText)
        }
    }

    private var speedBinding: Binding<ReplayPlaybackSpeed> {
        Binding(
            get: { speed },
            set: { newSpeed in
                MainActor.assumeIsolated {
                    onChangeSpeed(newSpeed)
                }
            }
        )
    }
}

struct ReplayTransportBarTheme {
    let accent: Color
    let primaryText: Color
    let secondaryText: Color
    let background: Color
    let border: Color
    let secondaryControlTint: Color

    static let lightPanel = ReplayTransportBarTheme(
        accent: .orange,
        primaryText: .primary,
        secondaryText: .secondary,
        background: Color.black.opacity(0.04),
        border: Color.black.opacity(0.08),
        secondaryControlTint: Color.black.opacity(0.10)
    )

    static let darkPanel = ReplayTransportBarTheme(
        accent: .cyan,
        primaryText: .white,
        secondaryText: Color.white.opacity(0.72),
        background: Color.white.opacity(0.08),
        border: Color.white.opacity(0.10),
        secondaryControlTint: Color.white.opacity(0.18)
    )
}
