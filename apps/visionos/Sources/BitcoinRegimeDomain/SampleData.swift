import Foundation

public enum BitcoinRegimeSampleData {
    public static func snapshot(now: Date = Date()) -> RegimeSnapshot {
        let sources = [
            SourceStamp(
                id: "mempool-space",
                name: "mempool.space",
                licenseClass: .a,
                cadence: "near-real-time",
                status: .live,
                fetchedAt: now,
                freshnessSeconds: 0,
                confidencePenalty: 0
            ),
            SourceStamp(
                id: "fred-dxy-demo",
                name: "FRED Broad Dollar Demo",
                licenseClass: .b,
                cadence: "daily",
                status: .demo,
                fetchedAt: now,
                freshnessSeconds: 0,
                confidencePenalty: 0.12
            ),
            SourceStamp(
                id: "fred-real-yield-demo",
                name: "FRED Real Yield Demo",
                licenseClass: .b,
                cadence: "daily",
                status: .demo,
                fetchedAt: now,
                freshnessSeconds: 0,
                confidencePenalty: 0.12
            ),
            SourceStamp(
                id: "fred-liquidity-demo",
                name: "FRED Liquidity Demo",
                licenseClass: .b,
                cadence: "weekly",
                status: .demo,
                fetchedAt: now,
                freshnessSeconds: 0,
                confidencePenalty: 0.16
            ),
            SourceStamp(
                id: "fred-risk-demo",
                name: "FRED Risk Proxy Demo",
                licenseClass: .b,
                cadence: "daily",
                status: .demo,
                fetchedAt: now,
                freshnessSeconds: 0,
                confidencePenalty: 0.12
            ),
            SourceStamp(
                id: "etf-flow-demo",
                name: "ETF Flow Demo Dataset",
                licenseClass: .b,
                cadence: "daily",
                status: .demo,
                fetchedAt: now,
                freshnessSeconds: 0,
                confidencePenalty: 0.18,
                note: "Partial coverage in MVP mode."
            ),
            SourceStamp(
                id: "mempool-price",
                name: "mempool.space BTC/USD",
                licenseClass: .a,
                cadence: "near-real-time",
                status: .live,
                fetchedAt: now,
                freshnessSeconds: 0,
                confidencePenalty: 0
            )
        ]

        let pricePhase = now.timeIntervalSinceReferenceDate / 600
        let priceUsd = 82_400 + sin(pricePhase) * 580 + cos(pricePhase * 1.7) * 160
        let deltaUsd = sin(pricePhase * 1.9) * 92

        return RegimeSnapshot(
            generatedAt: now,
            regime: RegimeState(
                key: .elevatedNetworkStress,
                label: "Busy Network, Worth Watching",
                summary: "Bitcoin traffic is elevated enough that sending coins is harder and the queue deserves a closer look.",
                alertLevel: .watch
            ),
            confidence: ConfidenceBreakdown(
                overall: 0.74,
                timeliness: 0.79,
                coverage: 0.68,
                agreement: 0.75,
                notes: [
                    "We can only see part of the large-buyer and macro picture in this MVP.",
                    "The main network data is fresh enough to support a useful read."
                ]
            ),
            scores: [
                ScoreCard(
                    key: "mempoolStress",
                    label: "Network Traffic",
                    value: 72,
                    direction: .elevated,
                    summary: "The Bitcoin network is crowded. Typical low-end fees are around 18 sat/vB, and the queue would take about 7.3 blocks to clear.",
                    contributionWeight: 0.42,
                    sourceIds: ["mempool-space"]
                ),
                ScoreCard(
                    key: "macroLiquidity",
                    label: "Broader Market Weather",
                    value: 61,
                    direction: .supportive,
                    summary: "The wider market backdrop is helping more than hurting. Money conditions are not strongly pushing investors away from risk.",
                    contributionWeight: 0.28,
                    sourceIds: ["fred-dxy-demo", "fred-real-yield-demo", "fred-liquidity-demo", "fred-risk-demo"]
                ),
                ScoreCard(
                    key: "knownFlowPressure",
                    label: "Big Buyer Activity",
                    value: 58,
                    direction: .supportive,
                    summary: "Tracked large buyers, including visible ETF flows, added about $185M. We can currently see 55% of the picture.",
                    contributionWeight: 0.3,
                    sourceIds: ["etf-flow-demo"]
                )
            ],
            evidence: [
                EvidenceCard(
                    id: "fee-floor",
                    title: "Base transaction cost",
                    valueLabel: "18 sat/vB floor",
                    interpretation: "Even after new blocks are mined, the cheapest workable fee stays high. That is a sign the queue is refilling quickly.",
                    direction: .elevated,
                    weight: 0.42,
                    freshnessLabel: "Live",
                    sourceIds: ["mempool-space"]
                ),
                EvidenceCard(
                    id: "macro-backdrop",
                    title: "Broader market backdrop",
                    valueLabel: "61/100",
                    interpretation: "Outside conditions are reasonably friendly for risk-taking, so macro is not putting heavy pressure on Bitcoin.",
                    direction: .supportive,
                    weight: 0.28,
                    freshnessLabel: "Demo",
                    sourceIds: ["fred-dxy-demo", "fred-real-yield-demo", "fred-liquidity-demo", "fred-risk-demo"]
                ),
                EvidenceCard(
                    id: "flow-context",
                    title: "Large tracked buying",
                    valueLabel: "$185M",
                    interpretation: "Visible large buyers are adding support. This mainly reflects public ETF data, and it is still only part of the full market.",
                    direction: .supportive,
                    weight: 0.3,
                    freshnessLabel: "Demo",
                    sourceIds: ["etf-flow-demo"]
                )
            ],
            marketWeather: MarketWeatherDetail(
                score: 61,
                outlook: "Mostly Sunny",
                summary: "The wider market backdrop is helping more than hurting. Money conditions are not strongly pushing investors away from risk.",
                components: [
                    MarketWeatherComponent(
                        id: "dollarIndex",
                        title: "Dollar Strength",
                        score: 70.6,
                        valueLabel: "123.4",
                        changeLabel: "Down 1.3 versus previous reading",
                        effect: .supportive,
                        weight: 0.30,
                        summary: "A softer dollar is easing pressure on global risk assets.",
                        sourceIds: ["fred-dxy-demo"]
                    ),
                    MarketWeatherComponent(
                        id: "realYield10y",
                        title: "10Y Real Yield",
                        score: 41.8,
                        valueLabel: "1.68%",
                        changeLabel: "Down 0.07% versus previous reading",
                        effect: .neutral,
                        weight: 0.30,
                        summary: "Real yields are not moving enough to dominate the current read.",
                        sourceIds: ["fred-real-yield-demo"]
                    ),
                    MarketWeatherComponent(
                        id: "liquidityProxy",
                        title: "Liquidity Proxy",
                        score: 56,
                        valueLabel: "7,216 bn",
                        changeLabel: "Up 36 bn versus previous reading",
                        effect: .neutral,
                        weight: 0.20,
                        summary: "Liquidity is stable enough that it is neither helping nor hurting much.",
                        sourceIds: ["fred-liquidity-demo"]
                    ),
                    MarketWeatherComponent(
                        id: "riskProxy",
                        title: "Risk-On Proxy",
                        score: 70.3,
                        valueLabel: "5,210",
                        changeLabel: "Up 42 versus previous reading",
                        effect: .supportive,
                        weight: 0.20,
                        summary: "Broader risk appetite is constructive and not pushing investors into defense.",
                        sourceIds: ["fred-risk-demo"]
                    )
                ]
            ),
            btcPrice: BitcoinPriceTicker(
                priceUsd: priceUsd,
                deltaUsd: deltaUsd,
                live: true,
                sourceIds: ["mempool-price"]
            ),
            narrative: "In plain English: Bitcoin traffic is elevated enough that sending coins is harder and the queue deserves a closer look. The clearest signals right now are base transaction cost and large tracked buying. Confidence is moderate (0.74) because some of the inputs are still partial or less timely than we would like.",
            actions: [
                ActionLink(id: "open-arena", label: "Open Fee Pressure Navigator", destination: "vision://arena"),
                ActionLink(id: "view-replay", label: "Replay Last 6 Hours", destination: "/v1/mempool/replay?range=6h&bucket=1m"),
                ActionLink(id: "view-methodology", label: "How This Is Calculated", destination: "/v1/methodology"),
                ActionLink(id: "save-snapshot", label: "Save This Snapshot", destination: "vision://snapshot/save")
            ],
            sources: sources
        )
    }

    public static func methodology(now: Date = Date()) -> MethodologyResponse {
        MethodologyResponse(
            updatedAt: now,
            scoreWeights: [
                "mempoolStress": [
                    "persistentFeeFloorPercentile": 0.35,
                    "queuedVBytesPercentile": 0.25,
                    "estimatedBlocksToClear": 0.20,
                    "postBlockRefillPersistence": 0.20
                ],
                "macroLiquidity": [
                    "dollarStrengthProxy": 0.30,
                    "realYield10yProxy": 0.30,
                    "liquidityProxy": 0.20,
                    "riskOnOffProxy": 0.20
                ],
                "knownFlowPressure": [
                    "netEtfFlowBias": 0.55,
                    "flowAcceleration": 0.25,
                    "coveragePenalty": 0.20
                ]
            ],
            sourceCatalog: [
                ["id": "mempool-space", "class": "A", "usage": "Live Bitcoin network traffic"],
                ["id": "fred-series", "class": "B", "usage": "Broader market backdrop"],
                ["id": "etf-flow-proxy", "class": "B", "usage": "Visible ETF and large-buyer flow context"]
            ],
            freshnessRules: [
                "Network traffic data refreshes each time the view is loaded.",
                "Broader market inputs are treated as delayed when they are more than two days old.",
                "Tracked flow inputs become stale after 36 hours."
            ],
            limitations: [
                "Large-buyer flow tracking is intentionally partial in MVP mode.",
                "Replay still uses sample history until saved snapshots are implemented.",
                "The broader market score describes the backdrop and does not predict price."
            ]
        )
    }

    public static func replay(
        range: ReplayRange = .sixHours,
        bucket: ReplayBucket = .oneMinute,
        now: Date = Date()
    ) -> ReplayTimeline {
        let totalMinutes = range == .twentyFourHours ? 24 * 60 : 6 * 60
        let step = bucket == .fiveMinutes ? 5 : 1
        let frameCount = totalMinutes / step
        let start = now.addingTimeInterval(TimeInterval(-totalMinutes * 60))
        var blockHeight = 886_000

        let frames = (0..<frameCount).map { index -> ReplayFrame in
            let minuteOffset = index * step
            let timestamp = start.addingTimeInterval(TimeInterval(minuteOffset * 60))
            let wave = sin(Double(index) / 5) * 8 + cos(Double(index) / 11) * 6
            let trend = range == .twentyFourHours ? sin(Double(index) / 17) * 4 : cos(Double(index) / 9) * 5
            let blockClearance = minuteOffset > 0 && minuteOffset.isMultiple(of: 10)
            let rawScore = max(22, min(94, 71 + wave + trend))
            let score = blockClearance ? max(20, rawScore - 7) : rawScore
            let queueBase = 2_600_000 + Int(score * 46_000)
            let queuedVBytes = max(
                900_000,
                queueBase - (blockClearance ? 720_000 : 0) + Int(sin(Double(index) / 3) * 110_000)
            )
            let minFee = max(4, min(44, Int(score / 4)))
            let maxFee = max(12, min(95, Int(score / 2.2)))

            if blockClearance {
                blockHeight += 1
            }

            return ReplayFrame(
                timestamp: timestamp,
                stateLabel: stateLabel(score: score),
                mempoolStressScore: score,
                queuedVBytes: queuedVBytes,
                estimatedBlocksToClear: ((Double(queuedVBytes) / 1_000_000) + score / 32).rounded(toPlaces: 1),
                feeBands: feeBands(totalQueuedVBytes: queuedVBytes, minFee: minFee, maxFee: maxFee),
                blockClearance: blockClearance
                    ? BlockClearance(blockHeight: blockHeight, clearedVBytes: 960_000, feeFloorAfter: Double(max(minFee - 4, 2)))
                    : nil
            )
        }

        return ReplayTimeline(
            generatedAt: now,
            range: range,
            bucket: bucket,
            frames: frames,
            source: SourceStamp(
                id: "replay-demo",
                name: "Replay Snapshot Generator",
                licenseClass: .a,
                cadence: "1m rolling snapshots",
                status: .demo,
                fetchedAt: now,
                freshnessSeconds: 0,
                confidencePenalty: 0.10,
                note: "Replace with persisted snapshots once storage is added."
            )
        )
    }

    private static func feeBands(totalQueuedVBytes: Int, minFee: Int, maxFee: Int) -> [FeeBand] {
        let weights: [Double] = [0.40, 0.28, 0.19, 0.13]
        let labels = ["Urgent", "Soon", "Base fee zone", "Low priority"]
        let lowerBounds = [max(maxFee - 8, minFee + 10), minFee + 8, minFee + 2, 1]
        let upperBounds = [maxFee, maxFee - 9, minFee + 7, minFee + 1]

        return weights.enumerated().map { index, weight in
            FeeBand(
                label: labels[index],
                minFee: Double(max(1, lowerBounds[index])),
                maxFee: Double(max(lowerBounds[index], upperBounds[index])),
                queuedVBytes: Int(Double(totalQueuedVBytes) * weight),
                estimatedBlocksToClear: (Double(totalQueuedVBytes) * weight / 1_000_000 + Double(index) * 0.6).rounded(toPlaces: 1)
            )
        }
    }

    private static func stateLabel(score: Double) -> String {
        if score >= 80 {
            return "Very busy, not clearing"
        }
        if score >= 68 {
            return "Busy and staying busy"
        }
        if score >= 52 {
            return "Manageable traffic"
        }
        return "Quiet"
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
