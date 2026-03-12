import Foundation

enum ReplayPlaybackSpeed: String, CaseIterable, Identifiable {
    case half
    case normal
    case double
    case quadruple

    var id: String { rawValue }

    var label: String {
        switch self {
        case .half:
            return "0.5x"
        case .normal:
            return "1x"
        case .double:
            return "2x"
        case .quadruple:
            return "4x"
        }
    }

    var interval: Duration {
        switch self {
        case .half:
            return .seconds(2)
        case .normal:
            return .seconds(1)
        case .double:
            return .milliseconds(500)
        case .quadruple:
            return .milliseconds(250)
        }
    }
}
