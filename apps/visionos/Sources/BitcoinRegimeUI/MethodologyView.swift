import BitcoinRegimeDomain
import SwiftUI

public struct MethodologyView: View {
    public let methodology: MethodologyResponse

    public init(methodology: MethodologyResponse) {
        self.methodology = methodology
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Text("How It Works")
                        .font(.title3.weight(.bold))
                    TileStatusBadge(state: .productive)
                }
                Spacer()
                Text(methodology.updatedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("The app combines a few simple ingredients. The percentages below show how much each ingredient matters inside each score.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(methodology.scoreWeights.keys.sorted(), id: \.self) { scoreKey in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            Text(humanizedScoreKey(scoreKey))
                                .font(.headline)
                            Spacer()
                            TileStatusBadge(state: .productive)
                        }
                        ForEach(methodology.scoreWeights[scoreKey]!.keys.sorted(), id: \.self) { weightKey in
                            HStack {
                                Text(humanizedWeightKey(weightKey))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(methodology.scoreWeights[scoreKey]![weightKey]!.formatted(.percent.precision(.fractionLength(0))))
                                    .font(.caption.weight(.semibold))
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.06))
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Limitations")
                    .font(.headline)
                ForEach(methodology.limitations, id: \.self) { limitation in
                    Text("• \(limitation)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private func humanizedScoreKey(_ key: String) -> String {
        switch key {
        case "mempoolStress":
            return "Network Traffic"
        case "macroLiquidity":
            return "Broader Market Weather"
        case "knownFlowPressure":
            return "Big Buyer Activity"
        default:
            return key
        }
    }

    private func humanizedWeightKey(_ key: String) -> String {
        switch key {
        case "persistentFeeFloorPercentile":
            return "How sticky the base fee is"
        case "queuedVBytesPercentile":
            return "How much demand is waiting"
        case "estimatedBlocksToClear":
            return "How many blocks the queue may need"
        case "postBlockRefillPersistence":
            return "How fast the queue refills after a block"
        case "dollarStrengthProxy":
            return "Dollar strength"
        case "realYield10yProxy":
            return "Real yields"
        case "liquidityProxy":
            return "Liquidity backdrop"
        case "riskOnOffProxy":
            return "Risk appetite"
        case "netEtfFlowBias":
            return "Net ETF flow"
        case "flowAcceleration":
            return "Whether flows are speeding up"
        case "coveragePenalty":
            return "Penalty for incomplete data"
        default:
            return key
        }
    }
}
