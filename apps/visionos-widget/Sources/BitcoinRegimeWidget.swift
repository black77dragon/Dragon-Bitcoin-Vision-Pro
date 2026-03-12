import BitcoinRegimeDomain
import SwiftUI
import WidgetKit

private enum BitcoinRegimeWidgetKind {
    static let price = "BitcoinPriceWidget"
    static let indicator = "BitcoinIndicatorWidget"
}

@available(visionOS 26.0, *)
struct BitcoinRegimeWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: RegimeSnapshot
}

@available(visionOS 26.0, *)
struct BitcoinRegimeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BitcoinRegimeWidgetEntry {
        BitcoinRegimeWidgetEntry(
            date: Date(),
            snapshot: BitcoinRegimeSampleData.snapshot()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BitcoinRegimeWidgetEntry) -> Void) {
        completion(loadEntry(isPreview: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BitcoinRegimeWidgetEntry>) -> Void) {
        let entry = loadEntry(isPreview: context.isPreview)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: entry.date)
            ?? entry.date.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadEntry(isPreview: Bool) -> BitcoinRegimeWidgetEntry {
        let snapshot = BitcoinRegimeWidgetSnapshotLoader().load(isPreview: isPreview)
        return BitcoinRegimeWidgetEntry(
            date: snapshot.generatedAt,
            snapshot: snapshot
        )
    }
}

@available(visionOS 26.0, *)
private struct BitcoinRegimeWidgetSnapshotLoader {
    private let cache: WidgetSnapshotCache

    init(cache: WidgetSnapshotCache = WidgetSnapshotCache()) {
        self.cache = cache
    }

    func load(isPreview: Bool) -> RegimeSnapshot {
        if isPreview {
            return BitcoinRegimeSampleData.snapshot()
        }

        if let export = try? cache.loadLatest() {
            return export.snapshot
        }

        return BitcoinRegimeSampleData.snapshot()
    }
}

@available(visionOS 26.0, *)
struct BitcoinPriceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: BitcoinRegimeWidgetKind.price,
            provider: BitcoinRegimeWidgetProvider()
        ) { entry in
            BitcoinPriceWidgetView(entry: entry)
        }
        .configurationDisplayName("BTC Price")
        .description("Current BTC price with change and timestamp.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@available(visionOS 26.0, *)
struct BitcoinIndicatorWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: BitcoinRegimeWidgetKind.indicator,
            provider: BitcoinRegimeWidgetProvider()
        ) { entry in
            BitcoinIndicatorWidgetView(entry: entry)
        }
        .configurationDisplayName("Network Traffic")
        .description("One key Bitcoin market indicator at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@available(visionOS 26.0, *)
private struct BitcoinPriceWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: BitcoinRegimeWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 10 : 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BTC")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("USD")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary.opacity(0.9))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.date, format: .dateTime.hour().minute())
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                    Text(entry.date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Text(priceLabel)
                .font(family == .systemSmall ? .title2.weight(.bold) : .system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            HStack(spacing: 8) {
                Image(systemName: deltaArrowName)
                    .font(.caption.weight(.bold))
                Text(deltaLabel)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                if family == .systemMedium {
                    Text(percentDeltaLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .foregroundStyle(deltaColor)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.97, blue: 0.98),
                    Color(red: 0.90, green: 0.93, blue: 0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var ticker: BitcoinPriceTicker? {
        entry.snapshot.btcPrice
    }

    private var priceLabel: String {
        guard let price = ticker?.priceUsd else {
            return "--"
        }

        return price.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    private var deltaValue: Double {
        ticker?.deltaUsd ?? 0
    }

    private var deltaColor: Color {
        if deltaValue > 0 {
            return Color(red: 0.11, green: 0.59, blue: 0.33)
        }

        if deltaValue < 0 {
            return Color(red: 0.79, green: 0.21, blue: 0.22)
        }

        return .secondary
    }

    private var deltaArrowName: String {
        if deltaValue > 0 {
            return "arrow.up.right"
        }

        if deltaValue < 0 {
            return "arrow.down.right"
        }

        return "minus"
    }

    private var deltaLabel: String {
        guard let delta = ticker?.deltaUsd else {
            return "0"
        }

        return delta.formatted(.currency(code: "USD").precision(.fractionLength(0)).sign(strategy: .always()))
    }

    private var percentDeltaLabel: String {
        guard let price = ticker?.priceUsd,
              let delta = ticker?.deltaUsd else {
            return "0.0%"
        }

        let prior = price - delta
        guard abs(prior) > 0.0001 else {
            return "0.0%"
        }

        let percent = (delta / prior) * 100
        return percent.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always())) + "%"
    }
}

@available(visionOS 26.0, *)
private struct BitcoinIndicatorWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: BitcoinRegimeWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 10 : 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("KEY INDICATOR")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(indicatorTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Text(entry.date, format: .dateTime.hour().minute())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(indicatorValue)
                    .font(.system(size: family == .systemSmall ? 42 : 50, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(indicatorColor)
                Text("/100")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                indicatorBadge
                if family == .systemMedium {
                    Text(directionLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(indicatorColor)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.11, blue: 0.15),
                    Color(red: 0.17, green: 0.19, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var indicator: ScoreCard? {
        entry.snapshot.scores.first(where: { $0.key == "mempoolStress" }) ?? entry.snapshot.scores.first
    }

    private var indicatorTitle: String {
        indicator?.label ?? "Indicator"
    }

    private var indicatorValue: String {
        guard let value = indicator?.value else {
            return "--"
        }

        return String(Int(value.rounded()))
    }

    private var directionLabel: String {
        switch indicator?.direction {
        case .supportive:
            return "Supportive"
        case .neutral:
            return "Neutral"
        case .restrictive:
            return "Restrictive"
        case .elevated:
            return "Elevated"
        case nil:
            return "Unavailable"
        }
    }

    private var indicatorColor: Color {
        switch indicator?.direction {
        case .supportive:
            return Color(red: 0.23, green: 0.79, blue: 0.57)
        case .neutral:
            return Color(red: 0.96, green: 0.76, blue: 0.25)
        case .restrictive, .elevated:
            return Color(red: 0.98, green: 0.42, blue: 0.32)
        case nil:
            return .white
        }
    }

    private var indicatorBadge: some View {
        Text(directionLabel.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(indicatorColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(indicatorColor.opacity(0.14), in: Capsule(style: .continuous))
    }
}

@available(visionOS 26.0, *)
@main
struct BitcoinRegimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        BitcoinPriceWidget()
        BitcoinIndicatorWidget()
    }
}
