import BitcoinRegimeDomain
import SwiftUI

public struct DailyBriefingView: View {
    public let snapshot: RegimeSnapshot
    public let onAction: (ActionLink) -> Void
    public let onOpenMarketWeather: () -> Void
    @State private var activeInfo: BriefingInfoContent?

    public init(
        snapshot: RegimeSnapshot,
        onAction: @escaping (ActionLink) -> Void = { _ in },
        onOpenMarketWeather: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.onAction = onAction
        self.onOpenMarketWeather = onOpenMarketWeather
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(snapshot.scores, id: \.key) { score in
                    ScoreCardTile(
                        score: score,
                        status: TileDeliveryState.from(sourceIds: score.sourceIds, sources: snapshot.sources),
                        onInfo: {
                            activeInfo = briefingInfo(for: score)
                        },
                        onDeepDive: score.key == "macroLiquidity" ? onOpenMarketWeather : nil
                    )
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("What This Read Is Based On")
                    .font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(snapshot.evidence, id: \.id) { card in
                            EvidenceTile(
                                card: card,
                                status: TileDeliveryState.from(sourceIds: card.sourceIds, sources: snapshot.sources),
                                onInfo: {
                                    activeInfo = briefingInfo(for: card)
                                }
                            )
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("In Plain English")
                    .font(.headline)
                Text(snapshot.narrative)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ForEach(snapshot.actions, id: \.id) { action in
                    if isNavigationAction(action) {
                        AppNavigationButton(
                            LocalizedStringKey(action.label),
                            systemImage: "arrow.up.forward.square"
                        ) {
                            onAction(action)
                        }
                    } else {
                        Button(action.label) {
                            onAction(action)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            HStack(spacing: 16) {
                if let macroScore = score(for: "macroLiquidity") {
                    SummaryStrip(
                        score: macroScore,
                        accent: .blue,
                        status: tileState(for: "macroLiquidity"),
                        onInfo: {
                            activeInfo = briefingInfo(for: macroScore)
                        },
                        onDeepDive: onOpenMarketWeather
                    )
                }
                if let flowScore = score(for: "knownFlowPressure") {
                    SummaryStrip(
                        score: flowScore,
                        accent: .teal,
                        status: tileState(for: "knownFlowPressure"),
                        onInfo: {
                            activeInfo = briefingInfo(for: flowScore)
                        },
                        onDeepDive: nil
                    )
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .sheet(item: $activeInfo) { info in
            BriefingInfoSheet(content: info)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Today's Read")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TileStatusBadge(
                            state: TileDeliveryState.from(
                                sourceIds: snapshot.sources.map(\.id),
                                sources: snapshot.sources
                            )
                        )
                    }
                    Text(snapshot.regime.label)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(snapshot.regime.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("This screen turns several market signals into a simpler read on whether Bitcoin demand looks healthy, stressed, or unclear.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    ConfidenceBadge(confidence: snapshot.confidence) {
                        activeInfo = briefingInfoForConfidence(snapshot.confidence)
                    }
                    Text(snapshot.generatedAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
        }
    }

    private func score(for key: String) -> ScoreCard? {
        snapshot.scores.first(where: { $0.key == key })
    }

    private func tileState(for key: String) -> TileDeliveryState {
        guard let score = snapshot.scores.first(where: { $0.key == key }) else {
            return .storeFront
        }

        return TileDeliveryState.from(sourceIds: score.sourceIds, sources: snapshot.sources)
    }

    private func isNavigationAction(_ action: ActionLink) -> Bool {
        action.destination == "vision://arena"
    }
}

public struct DemoShellView: View {
    @StateObject private var viewModel: BriefingViewModel
    private let onAction: (ActionLink) -> Void
    private let onOpenTrafficView: () -> Void
    private let onOpenMarketWeatherView: () -> Void
    private let onToggleImmersiveTrafficView: () -> Void
    private let isImmersiveTrafficActive: Bool

    public init(
        service: any RegimeService = DemoRegimeService(),
        onAction: @escaping (ActionLink) -> Void = { _ in },
        onOpenTrafficView: @escaping () -> Void = {},
        onOpenMarketWeatherView: @escaping () -> Void = {},
        onToggleImmersiveTrafficView: @escaping () -> Void = {},
        isImmersiveTrafficActive: Bool = false
    ) {
        _viewModel = StateObject(wrappedValue: BriefingViewModel(service: service))
        self.onAction = onAction
        self.onOpenTrafficView = onOpenTrafficView
        self.onOpenMarketWeatherView = onOpenMarketWeatherView
        self.onToggleImmersiveTrafficView = onToggleImmersiveTrafficView
        self.isImmersiveTrafficActive = isImmersiveTrafficActive
    }

    public var body: some View {
        Group {
            if let snapshot = viewModel.snapshot, let replay = viewModel.replay, let methodology = viewModel.methodology {
                HStack(alignment: .top, spacing: 20) {
                    DailyBriefingView(
                        snapshot: snapshot,
                        onAction: onAction,
                        onOpenMarketWeather: onOpenMarketWeatherView
                    )
                    VStack(spacing: 16) {
                        MempoolArenaView(
                            timeline: replay,
                            onOpenDetails: onOpenTrafficView,
                            onToggleImmersive: onToggleImmersiveTrafficView,
                            isImmersiveActive: isImmersiveTrafficActive
                        )
                        MethodologyView(methodology: methodology)
                    }
                    .frame(maxWidth: 520)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            } else if viewModel.isLoading {
                ProgressView("Loading briefing…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView("Unable to load briefing", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task {
            await viewModel.load()
        }
    }
}

private struct ScoreCardTile: View {
    let score: ScoreCard
    let status: TileDeliveryState
    let onInfo: () -> Void
    let onDeepDive: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        if let weatherStyle = weatherStyle {
                            Image(systemName: weatherStyle.symbolName)
                                .foregroundStyle(weatherStyle.tint)
                        }
                        Text(score.label)
                            .font(.headline)
                    }
                    TileStatusBadge(state: status)
                }
                Spacer()
                HStack(spacing: 10) {
                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Text("\(Int(score.value))/100")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(color)
                }
            }

            Text(score.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(scoreContextLine(for: score))
                .font(.footnote)
                .foregroundStyle(.secondary)

            ProgressView(value: score.value, total: 100)
                .tint(color)

            if let onDeepDive {
                Button(action: onDeepDive) {
                    Label("Open Weather Details", systemImage: "arrow.up.forward.square")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 182, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(color.opacity(0.12))
        )
    }

    private var weatherStyle: MarketWeatherForecastStyle? {
        guard score.key == "macroLiquidity" else {
            return nil
        }

        return marketWeatherForecastStyle(score: score.value)
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
    let status: TileDeliveryState
    let onInfo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(card.title)
                        .font(.headline)
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: onInfo) {
                            Image(systemName: "info.circle")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Text(card.freshnessLabel)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.15), in: Capsule())
                    }
                }

                TileStatusBadge(state: status)
            }

            Text(card.valueLabel)
                .font(.title3.weight(.semibold))

            Text(card.interpretation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(width: 290, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.08))
        )
    }
}

private struct SummaryStrip: View {
    let score: ScoreCard
    let accent: Color
    let status: TileDeliveryState
    let onInfo: () -> Void
    let onDeepDive: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                HStack(spacing: 8) {
                    if let weatherStyle = weatherStyle {
                        Image(systemName: weatherStyle.symbolName)
                            .foregroundStyle(weatherStyle.tint)
                    }
                    Text(summaryStripTitle(for: score.key))
                        .font(.headline)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    TileStatusBadge(state: status)
                }
            }
            Text(score.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let onDeepDive {
                Button(action: onDeepDive) {
                    Label("Deep Dive", systemImage: "arrow.up.forward.square")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(accent.opacity(0.12))
        )
    }

    private var weatherStyle: MarketWeatherForecastStyle? {
        guard score.key == "macroLiquidity" else {
            return nil
        }

        return marketWeatherForecastStyle(score: score.value)
    }
}

private struct ConfidenceBadge: View {
    let confidence: ConfidenceBreakdown
    let onInfo: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                Text("Confidence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(action: onInfo) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
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
