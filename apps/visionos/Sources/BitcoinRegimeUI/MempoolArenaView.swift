import BitcoinRegimeDomain
import SwiftUI

public struct MempoolArenaView: View {
    public let timeline: ReplayTimeline
    public let onOpenDetails: (() -> Void)?
    public let onToggleImmersive: (() -> Void)?
    public let isImmersiveActive: Bool
    @State private var selectedIndex: Int = 0
    @State private var isPlaying = false
    @State private var playbackSpeed: ReplayPlaybackSpeed = .normal

    public init(
        timeline: ReplayTimeline,
        onOpenDetails: (() -> Void)? = nil,
        onToggleImmersive: (() -> Void)? = nil,
        isImmersiveActive: Bool = false
    ) {
        self.timeline = timeline
        self.onOpenDetails = onOpenDetails
        self.onToggleImmersive = onToggleImmersive
        self.isImmersiveActive = isImmersiveActive
        _selectedIndex = State(initialValue: max(timeline.frames.count - 1, 0))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text("Fee Pressure Snapshot")
                        .font(.title2.weight(.bold))
                    TileStatusBadge(state: TileDeliveryState.from(source: timeline.source))
                }
                Text(activeFrame.stateLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                ReplayTransportBar(
                    isPlaying: isPlaying,
                    canInteract: timeline.frames.count > 1,
                    stageLabel: stageLabel,
                    timestamp: activeFrame.timestamp,
                    speed: playbackSpeed,
                    controlSize: .regular,
                    theme: .lightPanel,
                    onTogglePlayback: togglePlayback,
                    onStopPlayback: stopPlayback,
                    onChangeSpeed: { playbackSpeed = $0 }
                )

                VStack(spacing: 10) {
                    if let onOpenDetails {
                        LaunchActionButton(
                            title: "Open Fee Pressure Navigator",
                            subtitle: "Open the full decision view with watchpoints and fee guidance.",
                            badge: "Window",
                            systemImage: "arrow.up.forward.square",
                            accent: Color.cyan,
                            action: onOpenDetails
                        )
                    }

                    if let onToggleImmersive {
                        LaunchActionButton(
                            title: isImmersiveActive ? "Exit Immersive Navigator" : "Enter Immersive Navigator",
                            subtitle: isImmersiveActive
                                ? "Return from the room-scale navigator to the briefing."
                                : "Step into the room-scale globe to read pressure and next actions.",
                            badge: isImmersiveActive ? "Active" : "Immersive",
                            accent: isImmersiveActive
                                ? Color(red: 0.44, green: 0.86, blue: 0.78)
                                : Color(red: 1.0, green: 0.72, blue: 0.30),
                            usesLogoMark: true,
                            action: onToggleImmersive
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.10))
            )

            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(activeFrame.feeBands.indices, id: \.self) { index in
                        let band = activeFrame.feeBands[index]
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(bandColor(index).gradient)
                                .frame(
                                    width: max(geometry.size.width / CGFloat(activeFrame.feeBands.count) - 12, 28),
                                    height: max(CGFloat(band.queuedVBytes) / 35_000, 32)
                                )
                                .overlay(alignment: .top) {
                                    Text("\(Int(band.maxFee))")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.top, 8)
                                }

                            Text(band.label)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 260)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.08))
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatPill(title: "Traffic", value: "\(Int(activeFrame.mempoolStressScore))/100")
                    StatPill(title: "Waiting", value: queuedLabel(activeFrame.queuedVBytes))
                    StatPill(title: "Blocks to clear", value: String(format: "%.1f", activeFrame.estimatedBlocksToClear))
                }

                Slider(
                    value: Binding(
                        get: { Double(selectedIndex) },
                        set: { selectedIndex = min(max(Int($0.rounded()), 0), timeline.frames.count - 1) }
                    ),
                    in: 0...Double(max(timeline.frames.count - 1, 0)),
                    step: 1
                )

                if let clearance = activeFrame.blockClearance {
                    Text("Block \(clearance.blockHeight) cleared \(queuedLabel(clearance.clearedVBytes)) and lowered the base fee to \(Int(clearance.feeFloorAfter)) sat/vB.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text(isPlaying
                         ? "Replay is cycling through each pressure stage so you can see whether congestion is clearing or refilling."
                         : "Press play to step through pressure changes, then open the navigator when you need a clear send, wait, or pay-up decision.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.thinMaterial)
        )
        .task(id: isPlaying ? playbackSpeed : nil) {
            guard isPlaying, timeline.frames.count > 1 else {
                return
            }

            if selectedIndex >= timeline.frames.count - 1 {
                selectedIndex = 0
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: playbackSpeed.interval)

                guard !Task.isCancelled else {
                    break
                }

                selectedIndex = nextPlaybackIndex(after: selectedIndex)
            }
        }
        .onChange(of: timeline.frames.count) { _, frameCount in
            if frameCount < 2 {
                isPlaying = false
            }

            selectedIndex = min(max(selectedIndex, 0), max(frameCount - 1, 0))
        }
    }

    private var activeFrame: ReplayFrame {
        timeline.frames[min(max(selectedIndex, 0), max(timeline.frames.count - 1, 0))]
    }

    private func bandColor(_ index: Int) -> Color {
        switch index {
        case 0:
            return .red
        case 1:
            return .orange
        case 2:
            return .yellow
        default:
            return .mint
        }
    }

    private func queuedLabel(_ value: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(value))
    }

    private var stageLabel: String {
        let total = max(timeline.frames.count, 1)
        let current = min(max(selectedIndex + 1, 1), total)
        return "Stage \(current)/\(total)"
    }

    private func togglePlayback() {
        guard timeline.frames.count > 1 else {
            return
        }

        if !isPlaying, selectedIndex >= timeline.frames.count - 1 {
            selectedIndex = 0
        }

        isPlaying.toggle()
    }

    private func stopPlayback() {
        isPlaying = false
        selectedIndex = 0
    }

    private func nextPlaybackIndex(after currentIndex: Int) -> Int {
        guard timeline.frames.count > 1 else {
            return 0
        }

        return (currentIndex + 1) % timeline.frames.count
    }
}

private struct LaunchActionButton: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let badge: LocalizedStringKey
    let systemImage: String?
    let accent: Color
    let usesLogoMark: Bool
    let action: () -> Void

    init(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        badge: LocalizedStringKey,
        systemImage: String? = nil,
        accent: Color,
        usesLogoMark: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.systemImage = systemImage
        self.accent = accent
        self.usesLogoMark = usesLogoMark
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    actionMark

                    Spacer(minLength: 8)

                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accent.opacity(0.96))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(accent.opacity(0.15))
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.66))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 84, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(buttonBackground)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var actionMark: some View {
        if usesLogoMark {
            BitcoinRegimeLogoMark(size: 34)
        } else if let systemImage {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.14))
                    .frame(width: 36, height: 36)

                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
            }
        }
    }

    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.12),
                        accent.opacity(0.10),
                        Color.black.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                accent.opacity(0.32),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: accent.opacity(0.14), radius: 18, y: 10)
    }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.08))
        )
    }
}
