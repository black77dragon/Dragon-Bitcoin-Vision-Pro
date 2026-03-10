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
                id: "fred-macro-demo",
                name: "FRED Macro Demo",
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
            )
        ]

        return RegimeSnapshot(
            generatedAt: now,
            regime: RegimeState(
                key: .elevatedNetworkStress,
                label: "Elevated Network Stress",
                summary: "Persistent fee floors and healthy observable demand warrant a deeper arena review.",
                alertLevel: .watch
            ),
            confidence: ConfidenceBreakdown(
                overall: 0.74,
                timeliness: 0.79,
                coverage: 0.68,
                agreement: 0.75,
                notes: [
                    "Known flows remain partial in the MVP pipeline.",
                    "Live mempool inputs are strong enough to justify a regime read."
                ]
            ),
            scores: [
                ScoreCard(
                    key: "mempoolStress",
                    label: "Mempool Stress",
                    value: 72,
                    direction: .elevated,
                    summary: "Fee floor 18 sat/vB with 7.3 blocks to clear.",
                    contributionWeight: 0.42,
                    sourceIds: ["mempool-space"]
                ),
                ScoreCard(
                    key: "macroLiquidity",
                    label: "Macro Liquidity",
                    value: 61,
                    direction: .supportive,
                    summary: "Dollar and real yields are not aggressively restrictive.",
                    contributionWeight: 0.28,
                    sourceIds: ["fred-macro-demo"]
                ),
                ScoreCard(
                    key: "knownFlowPressure",
                    label: "Known Flow Pressure",
                    value: 58,
                    direction: .supportive,
                    summary: "$185M of observable ETF flow with 55% coverage.",
                    contributionWeight: 0.3,
                    sourceIds: ["etf-flow-demo"]
                )
            ],
            evidence: [
                EvidenceCard(
                    id: "fee-floor",
                    title: "Fee floor persistence",
                    valueLabel: "18 sat/vB floor",
                    interpretation: "Elevated fees are persisting after block clearances.",
                    direction: .elevated,
                    weight: 0.42,
                    freshnessLabel: "Live",
                    sourceIds: ["mempool-space"]
                ),
                EvidenceCard(
                    id: "macro-backdrop",
                    title: "Macro backdrop",
                    valueLabel: "61/100",
                    interpretation: "Macro conditions are not strongly fighting Bitcoin demand.",
                    direction: .supportive,
                    weight: 0.28,
                    freshnessLabel: "Demo",
                    sourceIds: ["fred-macro-demo"]
                ),
                EvidenceCard(
                    id: "flow-context",
                    title: "Known flow context",
                    valueLabel: "$185M",
                    interpretation: "Observable ETF demand is supportive, though coverage is partial.",
                    direction: .supportive,
                    weight: 0.3,
                    freshnessLabel: "Demo",
                    sourceIds: ["etf-flow-demo"]
                )
            ],
            narrative: "Regime: Elevated Network Stress. Evidence: fee floor persistence and known flow context. Confidence: 0.74.",
            actions: [
                ActionLink(id: "open-arena", label: "Open Mempool Arena", destination: "vision://arena"),
                ActionLink(id: "view-replay", label: "Replay 6H", destination: "/v1/mempool/replay?range=6h&bucket=1m"),
                ActionLink(id: "view-methodology", label: "View Methodology", destination: "/v1/methodology"),
                ActionLink(id: "save-snapshot", label: "Save Snapshot", destination: "vision://snapshot/save")
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
                ["id": "mempool-space", "class": "A", "usage": "Live mempool context"],
                ["id": "fred-series", "class": "B", "usage": "Macro backdrop"],
                ["id": "etf-flow-proxy", "class": "B", "usage": "Observable ETF flow context"]
            ],
            freshnessRules: [
                "Live mempool inputs update on request.",
                "Macro inputs degrade to delayed when the observation is older than two days.",
                "Known flows degrade to stale after 36 hours."
            ],
            limitations: [
                "Known flows are intentionally partial in MVP mode.",
                "Replay is fixture-backed until snapshot persistence is implemented.",
                "Macro scoring describes backdrop and does not predict price."
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
        let labels = ["Priority", "Competitive", "Sticky Floor", "Tail"]
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
            return "Structural congestion"
        }
        if score >= 68 {
            return "Elevated stress"
        }
        if score >= 52 {
            return "Normal to firm"
        }
        return "Calm"
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
