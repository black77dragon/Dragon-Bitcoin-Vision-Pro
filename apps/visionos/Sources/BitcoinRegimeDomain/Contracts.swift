import Foundation

public enum SourceLicenseClass: String, Codable, Sendable {
    case a = "A"
    case b = "B"
    case c = "C"
}

public enum SourceStatus: String, Codable, Sendable {
    case live
    case delayed
    case demo
    case stale
}

public enum ScoreDirection: String, Codable, Sendable {
    case supportive
    case neutral
    case restrictive
    case elevated
}

public enum AlertLevel: String, Codable, Sendable {
    case normal
    case watch
    case elevated
}

public enum RegimeStateKey: String, Codable, Sendable {
    case calmAccumulation
    case elevatedNetworkStress
    case speculativeSpike
    case distributionRisk
    case structurallyCongested
    case mixedEvidence
}

public enum ReplayRange: String, Codable, Sendable {
    case sixHours = "6h"
    case twentyFourHours = "24h"
}

public enum ReplayBucket: String, Codable, Sendable {
    case oneMinute = "1m"
    case fiveMinutes = "5m"
}

public struct SourceStamp: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let licenseClass: SourceLicenseClass
    public let cadence: String
    public let status: SourceStatus
    public let fetchedAt: Date
    public let publishedAt: Date?
    public let freshnessSeconds: Int
    public let confidencePenalty: Double
    public let note: String?

    public init(
        id: String,
        name: String,
        licenseClass: SourceLicenseClass,
        cadence: String,
        status: SourceStatus,
        fetchedAt: Date,
        publishedAt: Date? = nil,
        freshnessSeconds: Int,
        confidencePenalty: Double,
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.licenseClass = licenseClass
        self.cadence = cadence
        self.status = status
        self.fetchedAt = fetchedAt
        self.publishedAt = publishedAt
        self.freshnessSeconds = freshnessSeconds
        self.confidencePenalty = confidencePenalty
        self.note = note
    }
}

public struct ScoreCard: Codable, Hashable, Sendable {
    public let key: String
    public let label: String
    public let value: Double
    public let direction: ScoreDirection
    public let summary: String
    public let contributionWeight: Double
    public let sourceIds: [String]

    public init(
        key: String,
        label: String,
        value: Double,
        direction: ScoreDirection,
        summary: String,
        contributionWeight: Double,
        sourceIds: [String]
    ) {
        self.key = key
        self.label = label
        self.value = value
        self.direction = direction
        self.summary = summary
        self.contributionWeight = contributionWeight
        self.sourceIds = sourceIds
    }
}

public struct EvidenceCard: Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let valueLabel: String
    public let interpretation: String
    public let direction: ScoreDirection
    public let weight: Double
    public let freshnessLabel: String
    public let sourceIds: [String]

    public init(
        id: String,
        title: String,
        valueLabel: String,
        interpretation: String,
        direction: ScoreDirection,
        weight: Double,
        freshnessLabel: String,
        sourceIds: [String]
    ) {
        self.id = id
        self.title = title
        self.valueLabel = valueLabel
        self.interpretation = interpretation
        self.direction = direction
        self.weight = weight
        self.freshnessLabel = freshnessLabel
        self.sourceIds = sourceIds
    }
}

public struct MarketWeatherComponent: Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let score: Double
    public let valueLabel: String
    public let changeLabel: String
    public let effect: ScoreDirection
    public let weight: Double
    public let summary: String
    public let sourceIds: [String]

    public init(
        id: String,
        title: String,
        score: Double,
        valueLabel: String,
        changeLabel: String,
        effect: ScoreDirection,
        weight: Double,
        summary: String,
        sourceIds: [String]
    ) {
        self.id = id
        self.title = title
        self.score = score
        self.valueLabel = valueLabel
        self.changeLabel = changeLabel
        self.effect = effect
        self.weight = weight
        self.summary = summary
        self.sourceIds = sourceIds
    }
}

public struct MarketWeatherDetail: Codable, Hashable, Sendable {
    public let score: Double
    public let outlook: String
    public let summary: String
    public let components: [MarketWeatherComponent]

    public init(
        score: Double,
        outlook: String,
        summary: String,
        components: [MarketWeatherComponent]
    ) {
        self.score = score
        self.outlook = outlook
        self.summary = summary
        self.components = components
    }
}

public struct BitcoinPriceTicker: Codable, Hashable, Sendable {
    public let priceUsd: Double
    public let deltaUsd: Double?
    public let live: Bool
    public let sourceIds: [String]

    public init(
        priceUsd: Double,
        deltaUsd: Double? = nil,
        live: Bool,
        sourceIds: [String]
    ) {
        self.priceUsd = priceUsd
        self.deltaUsd = deltaUsd
        self.live = live
        self.sourceIds = sourceIds
    }
}

public struct ConfidenceBreakdown: Codable, Hashable, Sendable {
    public let overall: Double
    public let timeliness: Double
    public let coverage: Double
    public let agreement: Double
    public let notes: [String]

    public init(
        overall: Double,
        timeliness: Double,
        coverage: Double,
        agreement: Double,
        notes: [String]
    ) {
        self.overall = overall
        self.timeliness = timeliness
        self.coverage = coverage
        self.agreement = agreement
        self.notes = notes
    }
}

public struct RegimeState: Codable, Hashable, Sendable {
    public let key: RegimeStateKey
    public let label: String
    public let summary: String
    public let alertLevel: AlertLevel

    public init(key: RegimeStateKey, label: String, summary: String, alertLevel: AlertLevel) {
        self.key = key
        self.label = label
        self.summary = summary
        self.alertLevel = alertLevel
    }
}

public struct ActionLink: Codable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let destination: String

    public init(id: String, label: String, destination: String) {
        self.id = id
        self.label = label
        self.destination = destination
    }
}

public struct RegimeSnapshot: Codable, Hashable, Sendable {
    public let generatedAt: Date
    public let regime: RegimeState
    public let confidence: ConfidenceBreakdown
    public let scores: [ScoreCard]
    public let evidence: [EvidenceCard]
    public let marketWeather: MarketWeatherDetail?
    public let btcPrice: BitcoinPriceTicker?
    public let narrative: String
    public let actions: [ActionLink]
    public let sources: [SourceStamp]

    public init(
        generatedAt: Date,
        regime: RegimeState,
        confidence: ConfidenceBreakdown,
        scores: [ScoreCard],
        evidence: [EvidenceCard],
        marketWeather: MarketWeatherDetail? = nil,
        btcPrice: BitcoinPriceTicker? = nil,
        narrative: String,
        actions: [ActionLink],
        sources: [SourceStamp]
    ) {
        self.generatedAt = generatedAt
        self.regime = regime
        self.confidence = confidence
        self.scores = scores
        self.evidence = evidence
        self.marketWeather = marketWeather
        self.btcPrice = btcPrice
        self.narrative = narrative
        self.actions = actions
        self.sources = sources
    }
}

public struct FeeBand: Codable, Hashable, Sendable {
    public let label: String
    public let minFee: Double
    public let maxFee: Double
    public let queuedVBytes: Int
    public let estimatedBlocksToClear: Double

    public init(
        label: String,
        minFee: Double,
        maxFee: Double,
        queuedVBytes: Int,
        estimatedBlocksToClear: Double
    ) {
        self.label = label
        self.minFee = minFee
        self.maxFee = maxFee
        self.queuedVBytes = queuedVBytes
        self.estimatedBlocksToClear = estimatedBlocksToClear
    }
}

public struct BlockClearance: Codable, Hashable, Sendable {
    public let blockHeight: Int
    public let clearedVBytes: Int
    public let feeFloorAfter: Double

    public init(blockHeight: Int, clearedVBytes: Int, feeFloorAfter: Double) {
        self.blockHeight = blockHeight
        self.clearedVBytes = clearedVBytes
        self.feeFloorAfter = feeFloorAfter
    }
}

public struct ReplayFrame: Codable, Hashable, Sendable {
    public let timestamp: Date
    public let stateLabel: String
    public let mempoolStressScore: Double
    public let queuedVBytes: Int
    public let estimatedBlocksToClear: Double
    public let feeBands: [FeeBand]
    public let blockClearance: BlockClearance?

    public init(
        timestamp: Date,
        stateLabel: String,
        mempoolStressScore: Double,
        queuedVBytes: Int,
        estimatedBlocksToClear: Double,
        feeBands: [FeeBand],
        blockClearance: BlockClearance? = nil
    ) {
        self.timestamp = timestamp
        self.stateLabel = stateLabel
        self.mempoolStressScore = mempoolStressScore
        self.queuedVBytes = queuedVBytes
        self.estimatedBlocksToClear = estimatedBlocksToClear
        self.feeBands = feeBands
        self.blockClearance = blockClearance
    }
}

public struct ReplayTimeline: Codable, Hashable, Sendable {
    public let generatedAt: Date
    public let range: ReplayRange
    public let bucket: ReplayBucket
    public let frames: [ReplayFrame]
    public let source: SourceStamp

    public init(
        generatedAt: Date,
        range: ReplayRange,
        bucket: ReplayBucket,
        frames: [ReplayFrame],
        source: SourceStamp
    ) {
        self.generatedAt = generatedAt
        self.range = range
        self.bucket = bucket
        self.frames = frames
        self.source = source
    }
}

public struct MethodologyResponse: Codable, Hashable, Sendable {
    public let updatedAt: Date
    public let scoreWeights: [String: [String: Double]]
    public let sourceCatalog: [[String: String]]
    public let freshnessRules: [String]
    public let limitations: [String]

    public init(
        updatedAt: Date,
        scoreWeights: [String: [String: Double]],
        sourceCatalog: [[String: String]],
        freshnessRules: [String],
        limitations: [String]
    ) {
        self.updatedAt = updatedAt
        self.scoreWeights = scoreWeights
        self.sourceCatalog = sourceCatalog
        self.freshnessRules = freshnessRules
        self.limitations = limitations
    }
}

public struct SnapshotExport: Codable, Hashable, Sendable {
    public let savedAt: Date
    public let snapshot: RegimeSnapshot

    public init(savedAt: Date, snapshot: RegimeSnapshot) {
        self.savedAt = savedAt
        self.snapshot = snapshot
    }
}

public extension JSONDecoder {
    static func bitcoinRegimeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public extension JSONEncoder {
    static func bitcoinRegimeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
