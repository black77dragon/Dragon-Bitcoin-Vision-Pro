import BitcoinRegimeDomain
import BitcoinRegimeUI
import Charts
import RealityKit
import SwiftUI
import UIKit

@main
struct BitcoinRegimeNavigatorApp: App {
    private let service: any RegimeService
    @StateObject private var presentationState = AppPresentationState()
    private static let defaultAPIBaseURL = URL(string: "http://127.0.0.1:8787")!

    init() {
        if let baseURLString = ProcessInfo.processInfo.environment["BITCOIN_REGIME_API_BASE_URL"],
           let baseURL = URL(string: baseURLString) {
            service = FallbackRegimeService(primary: RegimeAPIClient(baseURL: baseURL))
        } else {
            service = FallbackRegimeService(primary: RegimeAPIClient(baseURL: Self.defaultAPIBaseURL))
        }
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            RootShellView(service: service, presentationState: presentationState)
        }
        .defaultSize(width: 1680, height: 960)

        WindowGroup(id: AppWindowID.spatialArena) {
            SpatialMempoolArenaWindow(service: service)
        }
        .defaultSize(width: 1440, height: 960)

        WindowGroup(id: AppWindowID.marketWeather) {
            MarketWeatherDetailWindow(service: service)
        }
        .defaultSize(width: 1480, height: 940)

        ImmersiveSpace(id: AppSpaceID.trafficGlobe) {
            ImmersiveTrafficSpaceContainer(
                service: service,
                presentationState: presentationState
            )
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}

private struct RootShellView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @ObservedObject var presentationState: AppPresentationState
    private let service: any RegimeService

    init(service: any RegimeService, presentationState: AppPresentationState) {
        self.service = service
        self.presentationState = presentationState
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {
                    AppChromeHeader()
                    AppChromeBitcoinVolatilityTile()
                    DemoShellView(
                        service: service,
                        onSnapshotLoaded: WidgetSnapshotWriter.save,
                        onAction: handleAction,
                        onOpenTrafficView: openTrafficView,
                        onOpenMarketWeatherView: openMarketWeatherView,
                        onToggleImmersiveTrafficView: toggleImmersiveTrafficView,
                        isImmersiveTrafficActive: presentationState.isTrafficGlobeImmersed
                    )
                }
                .frame(
                    minWidth: max(proxy.size.width - 96, 1320),
                    maxWidth: .infinity,
                    alignment: .topLeading
                )
                .padding(.horizontal, 36)
                .padding(.top, 42)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.visible, axes: .vertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.08, blue: 0.12),
                        Color(red: 0.11, green: 0.13, blue: 0.17)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }
    }

    private func handleAction(_ action: ActionLink) {
        switch action.destination {
        case "vision://arena":
            openTrafficView()
        case "vision://immersive-globe":
            toggleImmersiveTrafficView()
        default:
            break
        }
    }

    private func openTrafficView() {
        openWindow(id: AppWindowID.spatialArena)
    }

    private func openMarketWeatherView() {
        openWindow(id: AppWindowID.marketWeather)
    }

    private func toggleImmersiveTrafficView() {
        Task {
            if presentationState.isTrafficGlobeImmersed {
                await dismissImmersiveSpace()
                presentationState.isTrafficGlobeImmersed = false
            } else {
                switch await openImmersiveSpace(id: AppSpaceID.trafficGlobe) {
                case .opened:
                    presentationState.isTrafficGlobeImmersed = true
                case .error, .userCancelled:
                    presentationState.isTrafficGlobeImmersed = false
                @unknown default:
                    presentationState.isTrafficGlobeImmersed = false
                }
            }
        }
    }
}

private struct AppChromeHeader: View {
    private let metadata = AppBuildMetadata.current
    @StateObject private var priceModel = AppChromeBitcoinPriceModel()

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                BitcoinRegimeLogoLockup()

                HStack(spacing: 12) {
                    metadataPill(
                        title: "Version",
                        value: metadata.version
                    )

                    if let releaseDate = metadata.formattedReleaseDate {
                        metadataPill(
                            title: "Release Date",
                            value: releaseDate
                        )
                    }
                }
            }

            Spacer()

            if let ticker = priceModel.ticker {
                AppChromeBitcoinTickerCard(ticker: ticker)
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .trailing, spacing: 8) {
                    Text("Current Date & Time")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.62))
                    Text(context.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(context.date, format: .dateTime.hour().minute().second())
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(minWidth: 220, minHeight: AppChromeLayout.metricCardHeight, alignment: .trailing)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .task {
            await priceModel.start()
        }
    }

    @ViewBuilder
    private func metadataPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.62))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
    }
}

private enum AppChromeLayout {
    static let metricCardHeight: CGFloat = 96
}

private struct AppChromeBitcoinVolatilityTile: View {
    @StateObject private var model = AppChromeBitcoinVolatilityModel()
    @State private var selectedRange: BitcoinVolatilityRange = .oneYear

    private static let headlineFormatter = FloatingPointFormatStyle<Double>.number
        .precision(.fractionLength(1))

    private static let statFormatter = FloatingPointFormatStyle<Double>.number
        .precision(.fractionLength(1))

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            Divider()
                .overlay(Color.white.opacity(0.10))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(BitcoinVolatilityRange.allCases) { range in
                        Button {
                            selectedRange = range
                            Task {
                                await model.load(range: range)
                            }
                        } label: {
                            Text(range.label)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(range == selectedRange ? Color.black : .white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(range == selectedRange ? Color.white.opacity(0.90) : Color.white.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            Group {
                if let series = model.series(for: selectedRange) {
                    volatilityChart(series: series)
                    statisticsGrid(series: series)
                } else if model.isLoading {
                    ProgressView("Loading BTC volatility…")
                        .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
                } else {
                    ContentUnavailableView(
                        "BTC volatility unavailable",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text(model.errorMessage ?? "The volatility feed is currently unavailable.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .task {
            await model.start(initialRange: selectedRange)
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text("BTC-VOL")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Bitcoin Volatility")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.52))
                }

                HStack(spacing: 10) {
                    Text("30D REALIZED • PERCENT")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.56))

                    if let series = model.series(for: selectedRange) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(series.live ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(series.live ? "Live" : "Demo")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(series.live ? Color.green : Color.orange)
                        }
                    }
                }
            }

            Spacer(minLength: 12)

            if let series = model.series(for: selectedRange) {
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(series.currentValue.formatted(Self.headlineFormatter))%")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        if let delta = series.delta {
                            Text(deltaLabel(delta))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(deltaColor(for: delta))
                        }
                    }

                    Text(selectedRange.summaryLabel)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.56))
                }
            } else {
                VStack(alignment: .trailing, spacing: 6) {
                    Text(model.isLoading ? "Loading…" : "No Data")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(selectedRange.summaryLabel)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.56))
                }
            }
        }
    }

    @ViewBuilder
    private func volatilityChart(series: BitcoinVolatilitySeries) -> some View {
        Chart(series.points) { point in
            AreaMark(
                x: .value("Time", point.timestamp),
                y: .value("Volatility", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.40, blue: 0.30).opacity(0.32),
                        Color(red: 1.0, green: 0.40, blue: 0.30).opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Volatility", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color(red: 1.0, green: 0.34, blue: 0.24))
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        .chartYScale(domain: yScale(for: series.points))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7, dash: [5, 6]))
                    .foregroundStyle(Color.white.opacity(0.16))
                AxisTick()
                    .foregroundStyle(Color.white.opacity(0.18))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(xAxisLabel(for: date))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.72))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7))
                    .foregroundStyle(Color.white.opacity(0.12))
                AxisValueLabel {
                    if let level = value.as(Double.self) {
                        Text("\(level.formatted(Self.statFormatter))%")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.84))
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(height: 360)
    }

    @ViewBuilder
    private func statisticsGrid(series: BitcoinVolatilitySeries) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: 14)],
            alignment: .leading,
            spacing: 14
        ) {
            volatilityStatisticCell(title: "Open", value: "\(series.openValue.formatted(Self.statFormatter))%")
            volatilityStatisticCell(title: "High", value: "\(series.highValue.formatted(Self.statFormatter))%")
            volatilityStatisticCell(title: "Low", value: "\(series.lowValue.formatted(Self.statFormatter))%")
            volatilityStatisticCell(title: "Average", value: "\(series.averageValue.formatted(Self.statFormatter))%")
            volatilityStatisticCell(title: "Points", value: "\(series.points.count)")
            volatilityStatisticCell(title: "Source", value: series.live ? "Yahoo" : "Demo")
        }
    }

    @ViewBuilder
    private func volatilityStatisticCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.54))

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func yScale(for points: [BitcoinVolatilityPoint]) -> ClosedRange<Double> {
        let high = points.map(\.value).max() ?? 1
        let upperBound = max(100, (high / 25).rounded(.up) * 25)
        return 0...upperBound
    }

    private func xAxisLabel(for date: Date) -> String {
        switch selectedRange {
        case .oneDay:
            return date.formatted(.dateTime.hour().minute())
        case .oneWeek:
            return date.formatted(.dateTime.weekday(.abbreviated))
        case .oneMonth, .oneQuarter:
            return date.formatted(.dateTime.day().month(.abbreviated))
        case .oneYear, .fiveYears, .all:
            return date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
        }
    }

    private func deltaLabel(_ delta: Double) -> String {
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(delta.formatted(Self.headlineFormatter)) pts"
    }

    private func deltaColor(for delta: Double) -> Color {
        if delta > 0.05 {
            return .red
        }
        if delta < -0.05 {
            return .green
        }
        return Color.white.opacity(0.60)
    }
}

private enum BitcoinVolatilityRange: String, CaseIterable, Identifiable, Sendable {
    case oneDay = "1D"
    case oneWeek = "1W"
    case oneMonth = "1M"
    case oneQuarter = "1Q"
    case oneYear = "1Y"
    case fiveYears = "5Y"
    case all = "ALL"

    var id: String { rawValue }

    var label: String { rawValue }

    var summaryLabel: String {
        switch self {
        case .oneDay:
            return "1 Day"
        case .oneWeek:
            return "1 Week"
        case .oneMonth:
            return "1 Month"
        case .oneQuarter:
            return "1 Quarter"
        case .oneYear:
            return "1 Year"
        case .fiveYears:
            return "5 Years"
        case .all:
            return "All Time"
        }
    }

    var requestConfiguration: BitcoinVolatilityRequestConfiguration {
        switch self {
        case .oneDay, .oneWeek, .oneMonth:
            return BitcoinVolatilityRequestConfiguration(
                requestRange: "3mo",
                interval: "60m",
                samplingMode: .hourly
            )
        case .oneQuarter:
            return BitcoinVolatilityRequestConfiguration(
                requestRange: "6mo",
                interval: "60m",
                samplingMode: .hourly
            )
        case .oneYear:
            return BitcoinVolatilityRequestConfiguration(
                requestRange: "2y",
                interval: "1d",
                samplingMode: .daily
            )
        case .fiveYears:
            return BitcoinVolatilityRequestConfiguration(
                requestRange: "5y",
                interval: "1d",
                samplingMode: .daily
            )
        case .all:
            return BitcoinVolatilityRequestConfiguration(
                requestRange: "max",
                interval: "1d",
                samplingMode: .daily
            )
        }
    }

    var visibleDuration: TimeInterval? {
        switch self {
        case .oneDay:
            return 60 * 60 * 24
        case .oneWeek:
            return 60 * 60 * 24 * 7
        case .oneMonth:
            return 60 * 60 * 24 * 30
        case .oneQuarter:
            return 60 * 60 * 24 * 90
        case .oneYear:
            return 60 * 60 * 24 * 365
        case .fiveYears:
            return 60 * 60 * 24 * 365 * 5
        case .all:
            return nil
        }
    }

    var demoSpacing: TimeInterval {
        switch self {
        case .oneDay:
            return 60 * 5
        case .oneWeek:
            return 60 * 30
        case .oneMonth, .oneQuarter, .oneYear:
            return 60 * 60 * 24
        case .fiveYears:
            return 60 * 60 * 24 * 7
        case .all:
            return 60 * 60 * 24 * 30
        }
    }

    var demoPointCount: Int {
        switch self {
        case .oneDay:
            return 72
        case .oneWeek:
            return 90
        case .oneMonth:
            return 75
        case .oneQuarter:
            return 90
        case .oneYear:
            return 120
        case .fiveYears:
            return 140
        case .all:
            return 120
        }
    }
}

private struct BitcoinVolatilityPoint: Identifiable, Hashable, Sendable {
    let timestamp: Date
    let value: Double

    var id: Date { timestamp }
}

private struct BitcoinVolatilitySeries: Sendable {
    let range: BitcoinVolatilityRange
    let points: [BitcoinVolatilityPoint]
    let currentValue: Double
    let openValue: Double
    let highValue: Double
    let lowValue: Double
    let averageValue: Double
    let delta: Double?
    let live: Bool
}

private struct BitcoinVolatilityRequestConfiguration: Sendable {
    let requestRange: String
    let interval: String
    let samplingMode: BitcoinVolatilitySamplingMode
}

private enum BitcoinVolatilitySamplingMode: Sendable {
    case hourly
    case daily

    var rollingWindow: Int {
        switch self {
        case .hourly:
            return 24 * 30
        case .daily:
            return 30
        }
    }

    var periodsPerYear: Double {
        switch self {
        case .hourly:
            return 24 * 365
        case .daily:
            return 365
        }
    }
}

@MainActor
private final class AppChromeBitcoinVolatilityModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private var seriesByRange: [BitcoinVolatilityRange: BitcoinVolatilitySeries] = [:]

    private let client: LiveBitcoinVolatilityClient
    private var refreshTask: Task<Void, Never>?
    private var currentRange: BitcoinVolatilityRange

    init(client: LiveBitcoinVolatilityClient = LiveBitcoinVolatilityClient()) {
        self.client = client
        currentRange = .oneYear
    }

    deinit {
        refreshTask?.cancel()
    }

    func start(initialRange: BitcoinVolatilityRange) async {
        currentRange = initialRange

        if seriesByRange[initialRange] == nil {
            await load(range: initialRange)
        }

        guard refreshTask == nil else {
            return
        }

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(900))
                guard let self else {
                    return
                }
                await self.load(range: self.currentRange, forceRefresh: true)
            }
        }
    }

    func load(range: BitcoinVolatilityRange, forceRefresh: Bool = false) async {
        currentRange = range

        if !forceRefresh, seriesByRange[range] != nil {
            errorMessage = nil
            return
        }

        isLoading = seriesByRange[range] == nil
        errorMessage = nil

        do {
            seriesByRange[range] = try await client.fetchSeries(for: range)
        } catch {
            if seriesByRange[range] == nil {
                seriesByRange[range] = client.demoSeries(for: range)
            }
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func series(for range: BitcoinVolatilityRange) -> BitcoinVolatilitySeries? {
        seriesByRange[range]
    }
}

private struct LiveBitcoinVolatilityClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(
        baseURL: URL = AppChromeBitcoinVolatilityFeedConfiguration.baseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchSeries(for range: BitcoinVolatilityRange) async throws -> BitcoinVolatilitySeries {
        let configuration = range.requestConfiguration
        var components = URLComponents(
            url: baseURL.appending(path: "/v8/finance/chart/BTC-USD"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "range", value: configuration.requestRange),
            URLQueryItem(name: "interval", value: configuration.interval),
            URLQueryItem(name: "includePrePost", value: "false"),
            URLQueryItem(name: "events", value: "div,splits")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("BitcoinRegimeNavigator/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let payload = try decoder.decode(YahooChartResponse.self, from: data)

        guard
            let result = payload.chart.result?.first,
            let timestamps = result.timestamp,
            let closes = result.indicators.quote.first?.close
        else {
            throw URLError(.cannotParseResponse)
        }

        let samples = zip(timestamps, closes)
            .compactMap { timestamp, close -> PriceSample? in
                guard let close, close.isFinite, close > 0 else {
                    return nil
                }
                return PriceSample(timestamp: Date(timeIntervalSince1970: Double(timestamp)), close: close)
            }
            .sorted { $0.timestamp < $1.timestamp }

        let points = buildVisibleVolatilityPoints(
            from: samples,
            range: range,
            samplingMode: configuration.samplingMode
        )

        guard points.count >= 2 else {
            throw URLError(.cannotParseResponse)
        }

        return makeSeries(points: points, range: range, live: true)
    }

    func demoSeries(for range: BitcoinVolatilityRange, now: Date = Date()) -> BitcoinVolatilitySeries {
        let points = (0 ..< range.demoPointCount).map { index -> BitcoinVolatilityPoint in
            let distance = Double(range.demoPointCount - index - 1) * range.demoSpacing
            let timestamp = now.addingTimeInterval(-distance)
            let baseline = 42 + sin(Double(index) / 5.2) * 11 + cos(Double(index) / 13.0) * 7
            let ripple = sin(Double(index) / 2.7) * 2.6
            let value = max(14, baseline + ripple)
            return BitcoinVolatilityPoint(timestamp: timestamp, value: value)
        }

        return makeSeries(points: points, range: range, live: false)
    }

    private func buildVisibleVolatilityPoints(
        from samples: [PriceSample],
        range: BitcoinVolatilityRange,
        samplingMode: BitcoinVolatilitySamplingMode
    ) -> [BitcoinVolatilityPoint] {
        let allPoints = buildVolatilityPoints(from: samples, samplingMode: samplingMode)
        guard let visibleDuration = range.visibleDuration, let lastTimestamp = allPoints.last?.timestamp else {
            return allPoints
        }

        let visibleStart = lastTimestamp.addingTimeInterval(-visibleDuration)
        return allPoints.filter { $0.timestamp >= visibleStart }
    }

    private func buildVolatilityPoints(
        from samples: [PriceSample],
        samplingMode: BitcoinVolatilitySamplingMode
    ) -> [BitcoinVolatilityPoint] {
        guard samples.count >= 3 else {
            return []
        }

        let returns = zip(samples.dropFirst(), samples).compactMap { current, previous -> Double? in
            guard current.close > 0, previous.close > 0 else {
                return nil
            }
            return log(current.close / previous.close)
        }

        let window = min(max(samplingMode.rollingWindow, 2), returns.count)
        guard window >= 2 else {
            return []
        }

        let annualizationFactor = sqrt(samplingMode.periodsPerYear)
        var points: [BitcoinVolatilityPoint] = []
        points.reserveCapacity(max(returns.count - window + 1, 0))

        for upperBound in window ... returns.count {
            let slice = Array(returns[(upperBound - window) ..< upperBound])
            let mean = slice.reduce(0, +) / Double(slice.count)
            let variance = slice.reduce(0) { partial, value in
                partial + pow(value - mean, 2)
            } / Double(slice.count)
            let volatility = sqrt(max(variance, 0)) * annualizationFactor * 100

            guard volatility.isFinite else {
                continue
            }

            points.append(
                BitcoinVolatilityPoint(
                    timestamp: samples[upperBound].timestamp,
                    value: volatility
                )
            )
        }

        return points
    }

    private func makeSeries(
        points: [BitcoinVolatilityPoint],
        range: BitcoinVolatilityRange,
        live: Bool
    ) -> BitcoinVolatilitySeries {
        let sortedPoints = points.sorted { $0.timestamp < $1.timestamp }
        let currentValue = sortedPoints.last?.value ?? 0
        let openValue = sortedPoints.first?.value ?? currentValue
        let highValue = sortedPoints.map(\.value).max() ?? currentValue
        let lowValue = sortedPoints.map(\.value).min() ?? currentValue
        let averageValue = sortedPoints.map(\.value).reduce(0, +) / Double(max(sortedPoints.count, 1))
        let delta = sortedPoints.count > 1 ? currentValue - openValue : nil

        return BitcoinVolatilitySeries(
            range: range,
            points: sortedPoints,
            currentValue: currentValue,
            openValue: openValue,
            highValue: highValue,
            lowValue: lowValue,
            averageValue: averageValue,
            delta: delta,
            live: live
        )
    }

    private struct PriceSample: Sendable {
        let timestamp: Date
        let close: Double
    }

    private struct YahooChartResponse: Decodable {
        let chart: ChartContainer

        struct ChartContainer: Decodable {
            let result: [ChartResult]?
        }

        struct ChartResult: Decodable {
            let timestamp: [Int]?
            let indicators: Indicators
        }

        struct Indicators: Decodable {
            let quote: [Quote]
        }

        struct Quote: Decodable {
            let close: [Double?]
        }
    }
}

private enum AppChromeBitcoinVolatilityFeedConfiguration {
    static let baseURL: URL = {
        if let rawValue = ProcessInfo.processInfo.environment["BITCOIN_REGIME_VOLATILITY_FEED_BASE_URL"],
           let url = URL(string: rawValue) {
            return url
        }

        return URL(string: "https://query1.finance.yahoo.com")!
    }()
}

@MainActor
private final class AppChromeBitcoinPriceModel: ObservableObject {
    @Published private(set) var ticker: BitcoinPriceTicker?

    private let client: LiveBitcoinPriceClient
    private var refreshTask: Task<Void, Never>?

    init(client: LiveBitcoinPriceClient = LiveBitcoinPriceClient()) {
        self.client = client
    }

    deinit {
        refreshTask?.cancel()
    }

    func start() async {
        if ticker == nil {
            await refresh()
        }

        guard refreshTask == nil else {
            return
        }

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self else {
                    return
                }
                await self.refresh()
            }
        }
    }

    private func refresh() async {
        do {
            ticker = try await client.fetchTicker()
        } catch {
            // Keep the last successful quote on screen during transient feed errors.
        }
    }
}

private struct AppChromeBitcoinTickerCard: View {
    let ticker: BitcoinPriceTicker

    private static let priceFormatter = FloatingPointFormatStyle<Double>.Currency(code: "USD")
        .precision(.fractionLength(0...2))

    private static let deltaFormatter = FloatingPointFormatStyle<Double>.Currency(code: "USD")
        .sign(strategy: .always())
        .precision(.fractionLength(2))

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: 8) {
                Text("BTC / USD")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.62))

                if ticker.live {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Live")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.green)
                    }
                }
            }

            Text(ticker.priceUsd, format: Self.priceFormatter)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            if let deltaUsd = ticker.deltaUsd {
                HStack(spacing: 5) {
                    Image(systemName: deltaSymbol(for: deltaUsd))
                    Text(deltaUsd, format: Self.deltaFormatter)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(deltaColor(for: deltaUsd))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minWidth: 220, minHeight: AppChromeLayout.metricCardHeight, alignment: .trailing)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
    }

    private func deltaSymbol(for deltaUsd: Double) -> String {
        if deltaUsd > 0.009 {
            return "arrowtriangle.up.fill"
        }
        if deltaUsd < -0.009 {
            return "arrowtriangle.down.fill"
        }
        return "minus"
    }

    private func deltaColor(for deltaUsd: Double) -> Color {
        if deltaUsd > 0.009 {
            return .green
        }
        if deltaUsd < -0.009 {
            return .red
        }
        return Color.white.opacity(0.62)
    }
}

private struct LiveBitcoinPriceClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(
        baseURL: URL = AppChromeBitcoinPriceFeedConfiguration.baseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchTicker(now: Date = Date()) async throws -> BitcoinPriceTicker {
        let currentPriceUsd = try await fetchCurrentPriceUsd()
        let previousPriceUsd = try? await fetchHistoricalPriceUsd(timestamp: Int(now.timeIntervalSince1970) - 300)
        let deltaUsd = previousPriceUsd.map { roundCurrency(currentPriceUsd - $0) }

        return BitcoinPriceTicker(
            priceUsd: roundCurrency(currentPriceUsd),
            deltaUsd: deltaUsd,
            live: true,
            sourceIds: ["mempool-price"]
        )
    }

    private func fetchCurrentPriceUsd() async throws -> Double {
        let url = baseURL.appending(path: "/api/v1/prices")
        let payload: CurrentPricePayload = try await fetchDecodable(from: url)
        let priceUsd = payload.USD ?? payload.usd

        guard let priceUsd, priceUsd.isFinite else {
            throw URLError(.cannotParseResponse)
        }

        return priceUsd
    }

    private func fetchHistoricalPriceUsd(timestamp: Int) async throws -> Double {
        var components = URLComponents(
            url: baseURL.appending(path: "/api/v1/historical-price"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "currency", value: "USD"),
            URLQueryItem(name: "timestamp", value: String(timestamp))
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let data = try await fetchData(from: url)
        let payload = try JSONSerialization.jsonObject(with: data)

        guard let priceUsd = extractPriceValue(from: payload), priceUsd.isFinite else {
            throw URLError(.cannotParseResponse)
        }

        return priceUsd
    }

    private func fetchData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return data
    }

    private func fetchDecodable<Response: Decodable>(from url: URL) async throws -> Response {
        let data = try await fetchData(from: url)
        return try decoder.decode(Response.self, from: data)
    }

    private func extractPriceValue(from payload: Any) -> Double? {
        if let value = payload as? Double {
            return value
        }

        if let value = payload as? NSNumber {
            return value.doubleValue
        }

        if let value = payload as? String, let parsed = Double(value) {
            return parsed
        }

        if let array = payload as? [Any] {
            for entry in array {
                if let parsed = extractPriceValue(from: entry) {
                    return parsed
                }
            }
            return nil
        }

        guard let dictionary = payload as? [String: Any] else {
            return nil
        }

        for key in ["USD", "usd", "price", "amount", "value", "close", "last", "rate"] {
            if let parsed = dictionary[key].flatMap(extractPriceValue(from:)) {
                return parsed
            }
        }

        for key in ["data", "result", "prices", "price", "history", "values"] {
            if let parsed = dictionary[key].flatMap(extractPriceValue(from:)) {
                return parsed
            }
        }

        return nil
    }

    private func roundCurrency(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    private struct CurrentPricePayload: Decodable {
        let USD: Double?
        let usd: Double?
    }
}

private enum AppChromeBitcoinPriceFeedConfiguration {
    static let baseURL: URL = {
        if let rawValue = ProcessInfo.processInfo.environment["BITCOIN_REGIME_PRICE_FEED_BASE_URL"],
           let url = URL(string: rawValue) {
            return url
        }

        return URL(string: "https://mempool.space")!
    }()
}

private enum AppWindowID {
    static let spatialArena = "spatial-mempool-arena"
    static let marketWeather = "market-weather"
}

private enum AppSpaceID {
    static let trafficGlobe = "immersive-traffic-globe"
}

@MainActor
final class AppPresentationState: ObservableObject {
    @Published var isTrafficGlobeImmersed = false
}

private struct SpatialMempoolArenaWindow: View {
    @StateObject private var viewModel: ReplayWindowModel

    init(service: any RegimeService) {
        _viewModel = StateObject(wrappedValue: ReplayWindowModel(service: service))
    }

    var body: some View {
        Group {
            if let replay = viewModel.replay {
                NetworkTrafficGlobeWindowView(timeline: replay)
            } else if viewModel.isLoading {
                ProgressView("Loading network traffic…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.92).ignoresSafeArea())
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "Unable to load network traffic",
                    systemImage: "globe.badge.chevron.backward",
                    description: Text(errorMessage)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.92).ignoresSafeArea())
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.92).ignoresSafeArea())
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

private struct MarketWeatherDetailWindow: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MarketWeatherWindowModel

    init(service: any RegimeService) {
        _viewModel = StateObject(wrappedValue: MarketWeatherWindowModel(service: service))
    }

    var body: some View {
        Group {
            if let snapshot = viewModel.snapshot {
                MarketWeatherWindowView(snapshot: snapshot, onBack: navigateHome)
            } else if viewModel.isLoading {
                ProgressView("Loading market weather…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.92).ignoresSafeArea())
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "Unable to load market weather",
                    systemImage: "cloud.sun.bolt",
                    description: Text(errorMessage)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.92).ignoresSafeArea())
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.92).ignoresSafeArea())
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private func navigateHome() {
        dismiss()
    }
}

@MainActor
private final class ReplayWindowModel: ObservableObject {
    @Published private(set) var replay: ReplayTimeline?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: any RegimeService

    init(service: any RegimeService) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            replay = try await service.fetchReplay(range: .sixHours, bucket: .oneMinute)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

@MainActor
private final class MarketWeatherWindowModel: ObservableObject {
    @Published private(set) var snapshot: RegimeSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: any RegimeService

    init(service: any RegimeService) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            snapshot = try await service.fetchCurrentBriefing()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

@MainActor
private final class ReplaySceneModel: ObservableObject {
    @Published private(set) var replay: ReplayTimeline?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: any RegimeService

    init(service: any RegimeService) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            replay = try await service.fetchReplay(range: .sixHours, bucket: .oneMinute)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private struct ImmersiveTrafficSpaceContainer: View {
    @ObservedObject var presentationState: AppPresentationState
    @StateObject private var viewModel: ReplaySceneModel

    init(service: any RegimeService, presentationState: AppPresentationState) {
        self.presentationState = presentationState
        _viewModel = StateObject(wrappedValue: ReplaySceneModel(service: service))
    }

    var body: some View {
        Group {
            if let replay = viewModel.replay, !replay.frames.isEmpty {
                ImmersiveTrafficGlobeView(
                    timeline: replay,
                    presentationState: presentationState
                )
            } else if viewModel.isLoading {
                ProgressView("Loading immersive navigator…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.92).ignoresSafeArea())
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "Unable to load immersive navigator",
                    systemImage: "globe.americas.fill",
                    description: Text(errorMessage)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.92).ignoresSafeArea())
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.92).ignoresSafeArea())
            }
        }
        .task {
            presentationState.isTrafficGlobeImmersed = true
            await viewModel.load()
        }
        .onDisappear {
            presentationState.isTrafficGlobeImmersed = false
        }
    }
}

private struct ImmersiveTrafficGlobeView: View {
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @ObservedObject var presentationState: AppPresentationState
    let timeline: ReplayTimeline
    @StateObject private var controller = ImmersiveTrafficSceneController()
    @State private var tourStep = 0
    @State private var isTourPlaying = true

    init(timeline: ReplayTimeline, presentationState: AppPresentationState) {
        self.timeline = timeline
        self.presentationState = presentationState
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            let frame = ImmersiveTrafficFrame(timeline: timeline, now: context.date, tourStep: tourStep)

            ZStack(alignment: .top) {
                RealityView { content in
                    controller.installIfNeeded(in: content)
                    controller.update(with: frame)
                } update: { _ in
                    controller.update(with: frame)
                }

                immersiveHUD(frame: frame)
            }
        }
        .task(id: isTourPlaying) {
            guard isTourPlaying else {
                return
            }

            while !Task.isCancelled && isTourPlaying {
                try? await Task.sleep(for: .seconds(6))

                guard !Task.isCancelled, isTourPlaying else {
                    break
                }

                tourStep += 1
            }
        }
        .onDisappear {
            presentationState.isTrafficGlobeImmersed = false
        }
    }

    @ViewBuilder
    private func immersiveHUD(frame: ImmersiveTrafficFrame) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Settlement Pressure Flight Deck")
                    .font(.caption.weight(.black))
                    .foregroundStyle(frame.focusTint.opacity(0.94))
                Text(frame.focusTitle)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(frame.focusNarrative)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.76))
                    .frame(maxWidth: 460, alignment: .leading)

                HStack(spacing: 10) {
                    immersiveChip(title: "Tour", value: frame.routeOrdinalLabel, tint: frame.focusTint)
                    immersiveChip(title: "Queue", value: frame.queuedLabel, tint: frame.queueTint)
                    immersiveChip(title: "State", value: frame.activeFrame.stateLabel, tint: .cyan)
                    immersiveChip(title: "Lane", value: frame.routeLaneLabel, tint: frame.focusTint)
                }

                Text(frame.explorationPrompt)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.56))
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                ImmersiveHUDMetricCard(
                    title: "Recommended lane",
                    value: frame.recommendedLaneLabel,
                    detail: frame.recommendedFeeLabel,
                    tint: frame.actionTint
                )
                ImmersiveHUDMetricCard(
                    title: "Active corridor",
                    value: frame.routePressureShareLabel,
                    detail: frame.routeFeeLabel,
                    tint: frame.focusTint
                )
                ImmersiveHUDMetricCard(
                    title: "Next relief",
                    value: frame.nextReliefLabel,
                    detail: frame.nextReliefDetail,
                    tint: .mint
                )
            }

            VStack(alignment: .trailing, spacing: 12) {
                Text(frame.actionBadge)
                    .font(.caption.weight(.black))
                    .foregroundStyle(frame.actionTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(frame.actionTint.opacity(0.14), in: Capsule())

                HStack(spacing: 8) {
                    Button(action: previousTourStop) {
                        Label("Previous", systemImage: "backward.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(frame.routeCount < 2)

                    Button {
                        isTourPlaying.toggle()
                    } label: {
                        Label(isTourPlaying ? "Pause Tour" : "Play Tour", systemImage: isTourPlaying ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(frame.focusTint)
                    .disabled(frame.routeCount < 2)

                    Button(action: nextTourStop) {
                        Label("Next", systemImage: "forward.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(frame.routeCount < 2)
                }

                Button {
                    Task {
                        await dismissImmersiveSpace()
                        presentationState.isTrafficGlobeImmersed = false
                    }
                } label: {
                    Label("Exit Navigator", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .frame(maxWidth: 1360)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.48),
                            Color(red: 0.03, green: 0.09, blue: 0.16).opacity(0.66)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .padding(.top, 26)
        .padding(.horizontal, 26)
    }

    @ViewBuilder
    private func immersiveChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.48))
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.24), lineWidth: 1)
                )
        )
    }

    private func previousTourStop() {
        isTourPlaying = false
        tourStep -= 1
    }

    private func nextTourStop() {
        isTourPlaying = false
        tourStep += 1
    }
}

private struct ImmersiveHUDMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.58))
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text(detail)
                .font(.caption)
                .foregroundStyle(tint.opacity(0.92))
        }
        .frame(width: 178, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private struct ImmersiveRouteFocus {
    let catalogIndex: Int
    let route: SettlementPressureGlobeModel.Route
    let fromHub: SettlementPressureGlobeModel.Hub
    let toHub: SettlementPressureGlobeModel.Hub
    let band: FeeBand
    let load: Double
    let share: Double
    let midpointVector: SettlementPressureGlobeModel.Vector

    var title: String {
        "\(fromHub.name) to \(toHub.name)"
    }

    var pressureShareLabel: String {
        "\(Int((share * 100).rounded()))% of route pressure"
    }
}

private struct ImmersiveTrafficFrame {
    let activeFrame: ReplayFrame
    let previousFrame: ReplayFrame?
    let recentFrames: [ReplayFrame]
    let globeRotation: Float
    let globePitch: Float
    let sceneOffset: SIMD3<Float>
    let packetPhase: Float
    let pulsePhase: Float
    let travelPhase: Float
    let routeCount: Int
    let routeOrdinal: Int
    let focusRoute: ImmersiveRouteFocus?

    init(timeline: ReplayTimeline, now: Date, tourStep: Int) {
        guard !timeline.frames.isEmpty else {
            let fallback = ReplayFrame(
                timestamp: now,
                stateLabel: "No replay frames",
                mempoolStressScore: 0,
                queuedVBytes: 0,
                estimatedBlocksToClear: 0,
                feeBands: []
            )
            activeFrame = fallback
            previousFrame = nil
            recentFrames = [fallback]
            globeRotation = 0
            globePitch = 0
            sceneOffset = [0, 1.16, -1.28]
            packetPhase = 0
            pulsePhase = 0
            travelPhase = 0
            routeCount = 0
            routeOrdinal = 0
            focusRoute = nil
            return
        }

        let seconds = max(now.timeIntervalSince(timeline.generatedAt), 0)
        let index = Int(seconds.rounded(.down)) % timeline.frames.count

        activeFrame = timeline.frames[index]
        previousFrame = index > 0 ? timeline.frames[index - 1] : nil
        recentFrames = Array(timeline.frames[max(index - 15, 0)...index])
        packetPhase = Float((seconds * 0.18).truncatingRemainder(dividingBy: 1))
        pulsePhase = Float(seconds)
        travelPhase = Float((seconds * 0.09).truncatingRemainder(dividingBy: 1))

        let sortedRoutes = Self.routeFocuses(for: activeFrame)
        routeCount = sortedRoutes.count
        routeOrdinal = sortedRoutes.isEmpty ? 0 : positiveModulo(tourStep, sortedRoutes.count)
        focusRoute = sortedRoutes.isEmpty ? nil : sortedRoutes[routeOrdinal]

        if let focusRoute {
            let midpoint = focusRoute.midpointVector
            globeRotation = Float(atan2(-midpoint.x, midpoint.z)) + Float(sin(seconds * 0.14) * 0.04)
            globePitch = Float(-midpoint.y * 0.34)
            sceneOffset = [
                Float(midpoint.x) * 0.14,
                1.16 + Float(midpoint.y) * 0.10,
                -1.28
            ]
        } else {
            globeRotation = Float(seconds * 0.16)
            globePitch = 0
            sceneOffset = [0, 1.16, -1.28]
        }
    }

    var stressLevel: Float {
        Float(activeFrame.mempoolStressScore / 100)
    }

    var queuedLabel: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(activeFrame.queuedVBytes))
    }

    var focusTitle: String {
        focusRoute?.title ?? actionTitle
    }

    var focusNarrative: String {
        guard let focusRoute else {
            return actionSummary
        }

        return "Follow the \(focusRoute.band.label.lowercased()) corridor from \(focusRoute.fromHub.name) into \(focusRoute.toHub.name). This route is carrying \(focusRoute.pressureShareLabel.lowercased()), so it is the clearest place to inspect where pricing pressure is transmitting next."
    }

    var explorationPrompt: String {
        guard let focusRoute else {
            return "Walk around the globe to inspect pressure hot spots and packet flow."
        }

        return "Walk around the globe to compare \(focusRoute.fromHub.name) and \(focusRoute.toHub.name), then use the tour controls to jump to the next corridor."
    }

    var routeOrdinalLabel: String {
        guard routeCount > 0 else {
            return "No routes"
        }
        return "\(routeOrdinal + 1) of \(routeCount)"
    }

    var routeLaneLabel: String {
        focusRoute?.band.label ?? recommendedLaneLabel
    }

    var routeFeeLabel: String {
        guard let focusRoute else {
            return recommendedFeeLabel
        }
        return feeRangeLabel(for: focusRoute.band)
    }

    var routePressureShareLabel: String {
        focusRoute?.pressureShareLabel ?? "Stable flow"
    }

    var focusTint: Color {
        guard let focusRoute else {
            return actionTint
        }
        return SettlementPressureGlobeModel.routeColor(for: focusRoute.route.bandIndex)
    }

    var actionTitle: String {
        switch recommendedBandIndex {
        case 0:
            return "Delay non-urgent sends"
        case 1:
            return "Pay for certainty if timing matters"
        case 2:
            return "Standard settlement window is open"
        default:
            return "Low-fee window is open"
        }
    }

    var actionSummary: String {
        switch recommendedBandIndex {
        case 0:
            return "Urgent traffic is still stacked. Wait for the next clearance unless this transfer cannot slip."
        case 1:
            return "Pressure is elevated, so standard sends can drift upward. Pay into the faster lane if the next block matters."
        case 2:
            return "The queue is manageable enough that you can use the standard lane without overpaying."
        default:
            return "Lower-priority traffic is clearing cleanly, which makes this the best window for flexible settlement."
        }
    }

    var actionBadge: String {
        switch recommendedBandIndex {
        case 0:
            return "WAIT"
        case 1:
            return "PAY UP"
        case 2:
            return "SEND"
        default:
            return "CHEAP"
        }
    }

    var actionTint: Color {
        switch recommendedBandIndex {
        case 0:
            return .orange
        case 1:
            return .yellow
        case 2:
            return .mint
        default:
            return .cyan
        }
    }

    var recommendedLaneLabel: String {
        recommendedBand.label
    }

    var recommendedFeeLabel: String {
        feeRangeLabel(for: recommendedBand)
    }

    var nextReliefLabel: String {
        if activeFrame.blockClearance != nil {
            return "Now"
        }
        return "~\(estimatedMinutesToNextClearance)m"
    }

    var nextReliefDetail: String {
        if activeFrame.blockClearance != nil {
            return "Fresh block just opened a brief window"
        }
        if queueDelta < -120_000 {
            return "Cooling into the next cycle"
        }
        return "Estimated from recent block cadence"
    }

    var queueTint: Color {
        if queueDelta > 180_000 {
            return .orange
        }
        if queueDelta < -180_000 {
            return .mint
        }
        return .cyan
    }

    private var recommendedBandIndex: Int {
        if activeFrame.mempoolStressScore >= 84 || activeFrame.estimatedBlocksToClear >= 7 {
            return 0
        }
        if activeFrame.mempoolStressScore >= 66 || queueDelta > 180_000 {
            return min(1, max(activeFrame.feeBands.count - 1, 0))
        }
        if activeFrame.mempoolStressScore >= 48 {
            return min(2, max(activeFrame.feeBands.count - 1, 0))
        }
        return min(3, max(activeFrame.feeBands.count - 1, 0))
    }

    private var recommendedBand: FeeBand {
        guard activeFrame.feeBands.indices.contains(recommendedBandIndex) else {
            return FeeBand(label: "Observe", minFee: 0, maxFee: 0, queuedVBytes: 0, estimatedBlocksToClear: 0)
        }
        return activeFrame.feeBands[recommendedBandIndex]
    }

    private var queueDelta: Int {
        activeFrame.queuedVBytes - (previousFrame?.queuedVBytes ?? activeFrame.queuedVBytes)
    }

    private var estimatedMinutesToNextClearance: Int {
        guard let lastClearanceTimestamp else {
            return max(Int((activeFrame.estimatedBlocksToClear * 10 / 2).rounded()), 8)
        }

        let elapsedMinutes = activeFrame.timestamp.timeIntervalSince(lastClearanceTimestamp) / 60
        let remainingMinutes = max(averageClearanceIntervalMinutes - elapsedMinutes, 2)
        return Int(remainingMinutes.rounded())
    }

    private var lastClearanceTimestamp: Date? {
        recentFrames.last(where: { $0.blockClearance != nil })?.timestamp
    }

    private var averageClearanceIntervalMinutes: Double {
        let timestamps = recentFrames.compactMap { frame in
            frame.blockClearance != nil ? frame.timestamp : nil
        }

        guard timestamps.count >= 2 else {
            return 10
        }

        let intervals = zip(timestamps, timestamps.dropFirst()).map { previous, next in
            next.timeIntervalSince(previous) / 60
        }

        guard !intervals.isEmpty else {
            return 10
        }

        return intervals.reduce(0, +) / Double(intervals.count)
    }

    private func feeRangeLabel(for band: FeeBand) -> String {
        let minFee = Int(band.minFee.rounded())
        let maxFee = Int(band.maxFee.rounded())
        if minFee == maxFee {
            return "\(minFee) sat/vB"
        }
        return "\(minFee)-\(maxFee) sat/vB"
    }

    private static func routeFocuses(for frame: ReplayFrame) -> [ImmersiveRouteFocus] {
        let totalLoad = max(
            SettlementPressureGlobeModel.routes.reduce(0.0) { partial, route in
                partial + SettlementPressureGlobeModel.weightedBandLoad(for: route, frame: frame)
            },
            1.0
        )

        return SettlementPressureGlobeModel.routes.enumerated()
            .compactMap { catalogIndex, route in
                guard SettlementPressureGlobeModel.hubs.indices.contains(route.from),
                      SettlementPressureGlobeModel.hubs.indices.contains(route.to) else {
                    return nil
                }

                let band = frame.feeBands.indices.contains(route.bandIndex)
                    ? frame.feeBands[route.bandIndex]
                    : FeeBand(label: "Base", minFee: 0, maxFee: 0, queuedVBytes: 0, estimatedBlocksToClear: 0)
                let load = SettlementPressureGlobeModel.weightedBandLoad(for: route, frame: frame)

                return ImmersiveRouteFocus(
                    catalogIndex: catalogIndex,
                    route: route,
                    fromHub: SettlementPressureGlobeModel.hubs[route.from],
                    toHub: SettlementPressureGlobeModel.hubs[route.to],
                    band: band,
                    load: load,
                    share: load / totalLoad,
                    midpointVector: SettlementPressureGlobeModel.midpointVector(
                        from: SettlementPressureGlobeModel.hubs[route.from],
                        to: SettlementPressureGlobeModel.hubs[route.to]
                    )
                )
            }
            .sorted { lhs, rhs in
                if lhs.load == rhs.load {
                    return lhs.route.emphasis > rhs.route.emphasis
                }
                return lhs.load > rhs.load
            }
    }
}

@MainActor
private final class ImmersiveTrafficSceneController: ObservableObject {
    private let root = Entity()
    private let networkRoot = Entity()
    private let globeEntity = ModelEntity(
        mesh: .generateSphere(radius: 0.46),
        materials: [SimpleMaterial(color: UIColor(red: 0.08, green: 0.28, blue: 0.56, alpha: 1), roughness: 0.18, isMetallic: true)]
    )
    private let innerCoreEntity = ModelEntity(
        mesh: .generateSphere(radius: 0.20),
        materials: [SimpleMaterial(color: UIColor(red: 0.21, green: 0.76, blue: 0.91, alpha: 1), roughness: 0.02, isMetallic: false)]
    )
    private let orbitRingEntity = ModelEntity(
        mesh: .generateBox(width: 1.7, height: 0.003, depth: 1.7),
        materials: [SimpleMaterial(color: UIColor(red: 0.10, green: 0.28, blue: 0.35, alpha: 1), roughness: 0.9, isMetallic: false)]
    )
    private let travelBeaconEntity = ModelEntity(
        mesh: .generateSphere(radius: 0.018),
        materials: [SimpleMaterial(color: UIColor(red: 1.0, green: 0.84, blue: 0.28, alpha: 1), roughness: 0.03, isMetallic: true)]
    )

    private var hubEntities: [ModelEntity] = []
    private var packetEntities: [[ModelEntity]] = []
    private var routeMarkerEntities: [[ModelEntity]] = []
    private var towerEntities: [ModelEntity] = []
    private var haloEntities: [ModelEntity] = []
    private var installed = false

    func installIfNeeded(in content: RealityViewContent) {
        guard !installed else {
            if root.parent == nil {
                content.add(root)
            }
            return
        }

        root.position = [0, 1.16, -1.28]
        content.add(root)

        root.addChild(networkRoot)
        networkRoot.addChild(globeEntity)
        networkRoot.addChild(innerCoreEntity)
        networkRoot.addChild(travelBeaconEntity)

        orbitRingEntity.position = [0, -0.68, 0]
        orbitRingEntity.transform.rotation = simd_quatf(angle: .pi / 4, axis: [0, 1, 0])
        root.addChild(orbitRingEntity)

        for _ in Self.hubs.indices {
            let hub = ModelEntity(
                mesh: .generateSphere(radius: 0.022),
                materials: [SimpleMaterial(color: .white, roughness: 0.12, isMetallic: true)]
            )
            hubEntities.append(hub)
            networkRoot.addChild(hub)

            let halo = ModelEntity(
                mesh: .generateSphere(radius: 0.055),
                materials: [SimpleMaterial(color: UIColor(red: 0.22, green: 0.84, blue: 0.92, alpha: 1), roughness: 0.0, isMetallic: false)]
            )
            haloEntities.append(halo)
            networkRoot.addChild(halo)
        }

        for _ in Self.routes.indices {
            var routeMarkers: [ModelEntity] = []
            for _ in 0..<Self.routeMarkerCount {
                let marker = ModelEntity(
                    mesh: .generateSphere(radius: 0.007),
                    materials: [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.15), roughness: 0.02, isMetallic: true)]
                )
                routeMarkers.append(marker)
                networkRoot.addChild(marker)
            }
            routeMarkerEntities.append(routeMarkers)

            var packets: [ModelEntity] = []
            for _ in 0..<Self.packetCount {
                let packet = ModelEntity(
                    mesh: .generateSphere(radius: 0.010),
                    materials: [SimpleMaterial(color: UIColor(red: 0.98, green: 0.57, blue: 0.15, alpha: 1), roughness: 0.08, isMetallic: true)]
                )
                packets.append(packet)
                networkRoot.addChild(packet)
            }
            packetEntities.append(packets)
        }

        for _ in 0..<16 {
            let tower = ModelEntity(
                mesh: .generateBox(width: 0.055, height: 1.0, depth: 0.055),
                materials: [SimpleMaterial(color: UIColor(red: 0.21, green: 0.76, blue: 0.91, alpha: 1), roughness: 0.15, isMetallic: true)]
            )
            towerEntities.append(tower)
            root.addChild(tower)
        }

        installed = true
    }

    func update(with frame: ImmersiveTrafficFrame) {
        guard installed else {
            return
        }

        root.position = frame.sceneOffset

        let yawRotation = simd_quatf(angle: frame.globeRotation, axis: [0, 1, 0])
        let pitchRotation = simd_quatf(angle: frame.globePitch, axis: [1, 0, 0])
        networkRoot.transform.rotation = simd_mul(yawRotation, pitchRotation)

        let globeScale = 1 + frame.stressLevel * 0.10
        globeEntity.scale = SIMD3(repeating: globeScale)

        let innerPulse = 0.78 + (sin(frame.pulsePhase * 2.1) + 1) * 0.10 + frame.stressLevel * 0.12
        innerCoreEntity.scale = SIMD3(repeating: innerPulse)

        let activeEndpoints = Set(
            [frame.focusRoute?.route.from, frame.focusRoute?.route.to].compactMap { $0 }
        )

        for (index, node) in Self.hubs.enumerated() {
            let point = SettlementPressureGlobeModel.position(for: node, radius: Self.globeRadius + 0.02)
            let focusBoost: Float = activeEndpoints.contains(index) ? 0.30 : 0
            let intensity = max(
                0.28,
                min(1.0, frame.stressLevel * Float(node.bias) + pulse(for: index, phase: frame.pulsePhase) * 0.18 + focusBoost)
            )
            let color = Self.color(for: node.accent, alpha: 1.0)

            hubEntities[index].position = point
            hubEntities[index].scale = SIMD3(repeating: 0.70 + intensity * 0.78)
            hubEntities[index].model?.materials = [SimpleMaterial(color: color, roughness: 0.12, isMetallic: true)]

            haloEntities[index].position = point
            haloEntities[index].scale = SIMD3(repeating: 0.58 + intensity * 1.05)
            haloEntities[index].model?.materials = [
                SimpleMaterial(
                    color: color.withAlphaComponent(activeEndpoints.contains(index) ? 0.52 : 0.28),
                    roughness: 0.0,
                    isMetallic: false
                )
            ]
        }

        for (routeIndex, route) in Self.routes.enumerated() {
            guard Self.hubs.indices.contains(route.from), Self.hubs.indices.contains(route.to) else {
                continue
            }

            let fromHub = Self.hubs[route.from]
            let toHub = Self.hubs[route.to]
            let isFocused = routeIndex == frame.focusRoute?.catalogIndex
            let load = min(Float(SettlementPressureGlobeModel.weightedBandLoad(for: route, frame: frame.activeFrame)) / 1_600_000, 1.0)
            let routeColor = Self.bandColor(for: route.bandIndex)

            for (markerIndex, marker) in routeMarkerEntities[routeIndex].enumerated() {
                let progress = Self.routeMarkerCount == 1
                    ? 0
                    : Double(markerIndex) / Double(Self.routeMarkerCount - 1)
                marker.position = Self.arcPosition(from: fromHub, to: toHub, progress: progress, emphasis: route.emphasis)
                marker.scale = SIMD3(repeating: isFocused ? 1.35 : 0.78 + Float(route.emphasis) * 0.12)
                marker.model?.materials = [
                    SimpleMaterial(
                        color: routeColor.withAlphaComponent(isFocused ? 0.96 : CGFloat(0.16 + route.emphasis * 0.16)),
                        roughness: 0.02,
                        isMetallic: true
                    )
                ]
            }

            for (packetIndex, packet) in packetEntities[routeIndex].enumerated() {
                let progress = fmod(
                    Double(frame.packetPhase) + Double(packetIndex) / Double(Self.packetCount) + Double(routeIndex) * 0.08,
                    1
                )
                packet.position = Self.arcPosition(from: fromHub, to: toHub, progress: progress, emphasis: route.emphasis)
                packet.scale = SIMD3(repeating: (isFocused ? 1.0 : 0.72) + load * 0.82)
                packet.model?.materials = [
                    SimpleMaterial(
                        color: routeColor.withAlphaComponent(CGFloat(isFocused ? 0.88 : 0.48 + load * 0.20)),
                        roughness: 0.04,
                        isMetallic: true
                    )
                ]
            }

            if isFocused {
                travelBeaconEntity.isEnabled = true
                travelBeaconEntity.position = Self.arcPosition(
                    from: fromHub,
                    to: toHub,
                    progress: Double(frame.travelPhase),
                    emphasis: route.emphasis,
                    extraLift: 0.045
                )
                travelBeaconEntity.scale = SIMD3(repeating: 1.0 + load * 0.55 + frame.stressLevel * 0.22)
                travelBeaconEntity.model?.materials = [
                    SimpleMaterial(
                        color: routeColor.withAlphaComponent(1.0),
                        roughness: 0.01,
                        isMetallic: true
                    )
                ]
            }
        }

        if frame.focusRoute == nil {
            travelBeaconEntity.isEnabled = false
        }

        let samples = Array(frame.recentFrames.suffix(towerEntities.count))
        let count = max(samples.count, 1)

        for towerIndex in towerEntities.indices {
            let tower = towerEntities[towerIndex]

            guard towerIndex < samples.count else {
                tower.scale = [0.001, 0.001, 0.001]
                continue
            }

            let sample = samples[towerIndex]
            let stress = Float(sample.mempoolStressScore / 100)
            let angle = -1.18 + (Float(towerIndex) / Float(max(count - 1, 1))) * 2.36
            let radius: Float = 1.18
            let height = 0.10 + stress * 0.86
            let x = sin(angle) * radius
            let z = cos(angle) * 0.40 - 0.18
            let baseY: Float = -0.68
            let tint = Self.stressColor(for: stress)

            tower.position = [x, baseY + height / 2, z]
            tower.scale = [1.0, height, 1.0]
            tower.model?.materials = [SimpleMaterial(color: tint, roughness: 0.12, isMetallic: true)]
        }
    }

    private func pulse(for index: Int, phase: Float) -> Float {
        (sinf(phase * 2.7 + Float(index) * 0.9) + 1) * 0.5
    }

    private static func arcPosition(
        from: SettlementPressureGlobeModel.Hub,
        to: SettlementPressureGlobeModel.Hub,
        progress: Double,
        emphasis: Double,
        extraLift: Float = 0
    ) -> SIMD3<Float> {
        let vector = SettlementPressureGlobeModel.greatCircleVector(from: from, to: to, progress: progress)
        let lift = Float(sin(progress * .pi)) * (0.07 + Float(emphasis) * 0.07) + extraLift
        return SettlementPressureGlobeModel.position(for: vector, radius: globeRadius + 0.03 + lift)
    }

    private static func color(for accent: SettlementPressureGlobeModel.Accent, alpha: CGFloat) -> UIColor {
        switch accent {
        case .cyan:
            return UIColor(red: 0.25, green: 0.86, blue: 0.96, alpha: alpha)
        case .mint:
            return UIColor(red: 0.40, green: 0.95, blue: 0.76, alpha: alpha)
        case .yellow:
            return UIColor(red: 0.99, green: 0.78, blue: 0.24, alpha: alpha)
        case .orange:
            return UIColor(red: 0.98, green: 0.48, blue: 0.24, alpha: alpha)
        case .red:
            return UIColor(red: 0.98, green: 0.34, blue: 0.22, alpha: alpha)
        }
    }

    private static func bandColor(for bandIndex: Int) -> UIColor {
        switch bandIndex {
        case 0:
            return UIColor(red: 0.98, green: 0.34, blue: 0.22, alpha: 1)
        case 1:
            return UIColor(red: 0.99, green: 0.58, blue: 0.16, alpha: 1)
        case 2:
            return UIColor(red: 0.96, green: 0.82, blue: 0.22, alpha: 1)
        default:
            return UIColor(red: 0.34, green: 0.92, blue: 0.70, alpha: 1)
        }
    }

    private static func stressColor(for stress: Float) -> UIColor {
        if stress > 0.78 {
            return UIColor(red: 0.98, green: 0.36, blue: 0.20, alpha: 1)
        }
        if stress > 0.58 {
            return UIColor(red: 0.98, green: 0.62, blue: 0.20, alpha: 1)
        }
        return UIColor(red: 0.29, green: 0.86, blue: 0.84, alpha: 1)
    }

    private static let globeRadius: Float = 0.46
    private static let routeMarkerCount = 20
    private static let packetCount = 8
    private static let hubs = SettlementPressureGlobeModel.hubs
    private static let routes = SettlementPressureGlobeModel.routes
}

private func positiveModulo(_ value: Int, _ count: Int) -> Int {
    guard count > 0 else {
        return 0
    }

    let remainder = value % count
    return remainder >= 0 ? remainder : remainder + count
}

private struct AppBuildMetadata {
    let version: String
    let formattedReleaseDate: String?

    static let current: AppBuildMetadata = {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unversioned"
        let releaseDate = formatReleaseDate(bundle.object(forInfoDictionaryKey: "AppReleaseDate") as? String)
        return AppBuildMetadata(version: version, formattedReleaseDate: releaseDate)
    }()

    private static func formatReleaseDate(_ rawValue: String?) -> String? {
        guard let rawValue, let date = iso8601Formatter.date(from: rawValue) else {
            return rawValue
        }

        return displayFormatter.string(from: date)
    }

    private static let iso8601Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
