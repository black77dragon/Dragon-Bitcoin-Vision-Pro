import SwiftUI

public enum AppNavigationButtonProminence: Sendable {
    case primary
    case secondary
}

public struct AppNavigationButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String
    private let prominence: AppNavigationButtonProminence
    private let controlSize: ControlSize
    private let action: () -> Void

    public init(
        _ title: LocalizedStringKey,
        systemImage: String,
        prominence: AppNavigationButtonProminence = .primary,
        controlSize: ControlSize = .regular,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.prominence = prominence
        self.controlSize = controlSize
        self.action = action
    }

    public var body: some View {
        Group {
            switch prominence {
            case .primary:
                Button(action: action) {
                    Label(title, systemImage: systemImage)
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .tint(tintColor)
            case .secondary:
                Button(action: action) {
                    Label(title, systemImage: systemImage)
                }
                .buttonStyle(BorderedButtonStyle())
                .tint(tintColor)
            }
        }
        .controlSize(controlSize)
    }

    private var tintColor: Color {
        switch prominence {
        case .primary:
            return .cyan
        case .secondary:
            return Color.white.opacity(0.16)
        }
    }
}
