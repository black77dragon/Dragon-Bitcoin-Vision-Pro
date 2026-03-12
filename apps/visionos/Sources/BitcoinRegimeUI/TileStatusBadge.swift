import BitcoinRegimeDomain
import SwiftUI

enum TileDeliveryState {
    case productive
    case partial
    case mockup
    case storeFront

    var title: String {
        switch self {
        case .productive:
            return "Live"
        case .partial:
            return "Partial"
        case .mockup:
            return "Mockup"
        case .storeFront:
            return "Mockup"
        }
    }

    var emoji: String {
        switch self {
        case .productive:
            return "🟢"
        case .partial:
            return "🟠"
        case .mockup:
            return "🟡"
        case .storeFront:
            return "🟡"
        }
    }

    var tint: Color {
        switch self {
        case .productive:
            return .green
        case .partial:
            return .orange
        case .mockup:
            return .yellow
        case .storeFront:
            return .yellow
        }
    }

    static func from(source: SourceStamp?) -> TileDeliveryState {
        guard let source else {
            return .storeFront
        }

        return source.status == .demo ? .mockup : .productive
    }

    static func from(sourceIds: [String], sources: [SourceStamp]) -> TileDeliveryState {
        let matchedSources = sources.filter { sourceIds.contains($0.id) }
        guard !matchedSources.isEmpty else {
            return .storeFront
        }

        let demoCount = matchedSources.filter { $0.status == .demo }.count
        if demoCount == matchedSources.count {
            return .mockup
        }

        if demoCount > 0 {
            return .partial
        }

        return .productive
    }
}

struct TileStatusBadge: View {
    let state: TileDeliveryState

    var body: some View {
        Text("\(state.emoji) \(state.title)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(state.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(state.tint.opacity(0.14), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(state.tint.opacity(0.32), lineWidth: 1)
            }
    }
}
