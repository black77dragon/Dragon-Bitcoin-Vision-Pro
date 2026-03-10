import BitcoinRegimeDomain
import SwiftUI

public struct DailyBriefingView: View {
    public let snapshot: RegimeSnapshot
    public let onAction: (ActionLink) -> Void

    public init(snapshot: RegimeSnapshot, onAction: @escaping (ActionLink) -> Void = { _ in }) {
        self.snapshot = snapshot
        self.onAction = onAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(snapshot.scores, id: \.key) { score in
                    ScoreCardTile(score: score)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Evidence")
                    .font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(snapshot.evidence, id: \.id) { card in
                            EvidenceTile(card: card)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Narrative")
                    .font(.headline)
                Text(snapshot.narrative)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ForEach(snapshot.actions, id: \.id) { action in
                    Button(action.label) {
                        onAction(action)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            HStack(spacing: 16) {
                SummaryStrip(
                    title: "Macro Strip",
                    subtitle: scoreSummary(for: "macroLiquidity"),
                    accent: .blue
                )
                SummaryStrip(
                    title: "Known Flows",
                    subtitle: scoreSummary(for: "knownFlowPressure"),
                    accent: .teal
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.regime.label)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(snapshot.regime.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    ConfidenceBadge(confidence: snapshot.confidence)
                    Text(snapshot.generatedAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
        }
    }

    private func scoreSummary(for key: String) -> String {
        snapshot.scores.first(where: { $0.key == key })?.summary ?? "Unavailable"
    }
}

public struct DemoShellView: View {
    @StateObject private var viewModel: BriefingViewModel

    public init(service: any RegimeService = DemoRegimeService()) {
        _viewModel = StateObject(wrappedValue: BriefingViewModel(service: service))
    }

    public var body: some View {
        Group {
            if let snapshot = viewModel.snapshot, let replay = viewModel.replay, let methodology = viewModel.methodology {
                HStack(alignment: .top, spacing: 20) {
                    DailyBriefingView(snapshot: snapshot)
                    VStack(spacing: 16) {
                        MempoolArenaView(timeline: replay)
                        MethodologyView(methodology: methodology)
                    }
                    .frame(maxWidth: 520)
                }
                .padding(20)
            } else if viewModel.isLoading {
                ProgressView("Loading briefing…")
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView("Unable to load briefing", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else {
                ProgressView()
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

private struct ScoreCardTile: View {
    let score: ScoreCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(score.label)
                    .font(.headline)
                Spacer()
                Text("\(Int(score.value))/100")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
            }

            Text(score.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView(value: score.value, total: 100)
                .tint(color)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(color.opacity(0.12))
        )
    }

    private var color: Color {
        switch score.direction {
        case .supportive:
            return .green
        case .neutral:
            return .yellow
        case .restrictive:
            return .orange
        case .elevated:
            return .red
        }
    }
}

private struct EvidenceTile: View {
    let card: EvidenceCard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(card.title)
                    .font(.headline)
                Spacer()
                Text(card.freshnessLabel)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.15), in: Capsule())
            }

            Text(card.valueLabel)
                .font(.title3.weight(.semibold))

            Text(card.interpretation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(width: 250, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
    }
}

private struct SummaryStrip: View {
    let title: String
    let subtitle: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(accent.opacity(0.12))
        )
    }
}

private struct ConfidenceBadge: View {
    let confidence: ConfidenceBreakdown

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Confidence")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(confidence.overall.formatted(.number.precision(.fractionLength(2))))
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(confidence.notes.first ?? "")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 180)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
    }
}
