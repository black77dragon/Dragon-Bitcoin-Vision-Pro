import BitcoinRegimeDomain
import SwiftUI

public struct MempoolArenaView: View {
    public let timeline: ReplayTimeline
    @State private var selectedIndex: Int = 0

    public init(timeline: ReplayTimeline) {
        self.timeline = timeline
        _selectedIndex = State(initialValue: max(timeline.frames.count - 1, 0))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mempool Arena")
                        .font(.title2.weight(.bold))
                    Text(activeFrame.stateLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(activeFrame.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
                    StatPill(title: "Stress", value: "\(Int(activeFrame.mempoolStressScore))/100")
                    StatPill(title: "Queued", value: queuedLabel(activeFrame.queuedVBytes))
                    StatPill(title: "Blocks", value: String(format: "%.1f", activeFrame.estimatedBlocksToClear))
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
                    Text("Block \(clearance.blockHeight) cleared \(queuedLabel(clearance.clearedVBytes)) and dropped the floor to \(Int(clearance.feeFloorAfter)) sat/vB.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Scrub the replay to inspect whether current congestion is persistent or event-driven.")
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
