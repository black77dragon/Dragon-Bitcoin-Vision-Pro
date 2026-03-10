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
                Text("Methodology")
                    .font(.title3.weight(.bold))
                Spacer()
                Text(methodology.updatedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(methodology.scoreWeights.keys.sorted(), id: \.self) { scoreKey in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(scoreKey)
                            .font(.headline)
                        ForEach(methodology.scoreWeights[scoreKey]!.keys.sorted(), id: \.self) { weightKey in
                            HStack {
                                Text(weightKey)
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
}
