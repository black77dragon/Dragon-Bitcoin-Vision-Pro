import BitcoinRegimeDomain
import SwiftUI

public struct MarketWeatherWindowView: View {
    public let snapshot: RegimeSnapshot
    public let onBack: (() -> Void)?

    public init(snapshot: RegimeSnapshot, onBack: (() -> Void)? = nil) {
        self.snapshot = snapshot
        self.onBack = onBack
    }

    public var body: some View {
        Group {
            if let weather = snapshot.marketWeather {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header(weather: weather)

                        HStack(alignment: .top, spacing: 24) {
                            outlookPanel(weather: weather)
                                .frame(maxWidth: .infinity)

                            VStack(spacing: 16) {
                                currentSourcesPanel(weather: weather)
                                liveProposalPanel
                            }
                            .frame(width: 420)
                        }

                        componentGrid(weather: weather)
                    }
                    .padding(28)
                }
                .background(background.ignoresSafeArea())
            } else {
                ContentUnavailableView(
                    "Weather Detail Unavailable",
                    systemImage: "cloud.slash",
                    description: Text("This snapshot does not include the macro weather breakdown yet.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(background.ignoresSafeArea())
            }
        }
    }

    @ViewBuilder
    private func header(weather: MarketWeatherDetail) -> some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                if let onBack {
                    AppNavigationButton(
                        "Back",
                        systemImage: "chevron.backward",
                        prominence: .secondary,
                        controlSize: .large,
                        action: onBack
                    )
                }

                Text("Broader Market Weather")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("A market forecast for Bitcoin demand based on dollar strength, real yields, liquidity, and risk appetite.")
                    .font(.body)
                    .foregroundStyle(Color.white.opacity(0.74))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text("Snapshot Time")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
                Text(snapshot.generatedAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(snapshot.generatedAt, format: .dateTime.hour().minute().second())
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
                Text("Overall weather: \(weather.outlook)")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.68))
            }
        }
        .padding(22)
        .background(panelBackground)
    }

    @ViewBuilder
    private func outlookPanel(weather: MarketWeatherDetail) -> some View {
        let style = marketWeatherForecastStyle(score: weather.score)

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    Circle()
                        .fill(style.tint.opacity(0.18))
                        .frame(width: 88, height: 88)
                    Image(systemName: style.symbolName)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(style.tint)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(style.label)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(Int(weather.score))/100 weather score")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.86))
                }
            }

            Text(weather.summary)
                .font(.body)
                .foregroundStyle(Color.white.opacity(0.76))

            Divider()
                .overlay(Color.white.opacity(0.10))

            VStack(alignment: .leading, spacing: 10) {
                Text("What makes up the weather")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(weather.components, id: \.id) { component in
                    HStack {
                        Text(component.title)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(Int(component.weight * 100))%")
                            .foregroundStyle(Color.white.opacity(0.68))
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding(24)
        .background(panelBackground)
    }

    @ViewBuilder
    private func currentSourcesPanel(weather: MarketWeatherDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Current Sources")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(weather.components, id: \.id) { component in
                if let source = source(for: component) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(component.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(source.name)
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.68))
                            Text(source.cadence)
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.56))
                        }

                        Spacer()

                        TileStatusBadge(
                            state: TileDeliveryState.from(sourceIds: [source.id], sources: snapshot.sources)
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(sidePanelBackground)
    }

    @ViewBuilder
    private var liveProposalPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Go Live Proposal")
                .font(.headline)
                .foregroundStyle(.white)

            ProposalBlock(
                title: "Composition",
                lines: [
                    "Keep the weather score as a weighted blend of dollar strength, 10Y real yields, liquidity, and risk appetite.",
                    "Use the same 30/30/20/20 weighting already implemented so design and backend stay aligned at launch."
                ]
            )

            ProposalBlock(
                title: "Data Sources",
                lines: [
                    "Use a server-side macro composite feed as the production source of truth.",
                    "FRED already covers the current starter set: DTWEXBGS for the broad dollar, DFII10 for 10Y real yield, WALCL for liquidity, and SP500 for risk appetite.",
                    "Upgrade faster-moving market inputs to a market-data vendor when intraday freshness matters, while keeping slower liquidity series on their natural cadence."
                ]
            )

            ProposalBlock(
                title: "Rollout",
                lines: [
                    "Phase 1: publish one normalized weather payload from the backend and fall back to delayed data when a metric is missing.",
                    "Phase 2: add intraday market feeds for DXY, Treasury yields, and equity risk proxies while keeping slower liquidity series on their normal cadence."
                ]
            )
        }
        .padding(20)
        .background(sidePanelBackground)
    }

    @ViewBuilder
    private func componentGrid(weather: MarketWeatherDetail) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(weather.components, id: \.id) { component in
                componentCard(component)
            }
        }
    }

    @ViewBuilder
    private func componentCard(_ component: MarketWeatherComponent) -> some View {
        let style = marketWeatherForecastStyle(component: component)

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: style.symbolName)
                    .font(.title2)
                    .foregroundStyle(style.tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(component.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(style.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.66))
                }

                Spacer()

                Text("\(Int(component.score))/100")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }

            HStack {
                Text(component.valueLabel)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(component.changeLabel)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.66))
            }

            Text(component.summary)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.74))

            ProgressView(value: component.score, total: 100)
                .tint(style.tint)

            if let source = source(for: component) {
                HStack {
                    Text(source.name)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.64))
                    Spacer()
                    Text("\(Int(component.weight * 100))% weight")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.72))
                }
            }
        }
        .padding(20)
        .background(panelBackground)
    }

    private func source(for component: MarketWeatherComponent) -> SourceStamp? {
        snapshot.sources.first(where: { component.sourceIds.contains($0.id) })
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.08, blue: 0.14),
                Color(red: 0.06, green: 0.11, blue: 0.18),
                Color(red: 0.11, green: 0.12, blue: 0.17)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }

    private var sidePanelBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

private struct ProposalBlock: View {
    let title: String
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)

            ForEach(lines, id: \.self) { line in
                Label(line, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.74))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }
}
