import BitcoinRegimeDomain
import BitcoinRegimeUI
import SwiftUI

@main
struct BitcoinRegimeNavigatorApp: App {
    var body: some Scene {
        WindowGroup {
            RootShellView()
        }
        .defaultSize(width: 1680, height: 960)
    }
}

private struct RootShellView: View {
    private let service: any RegimeService

    init() {
        if let baseURLString = ProcessInfo.processInfo.environment["BITCOIN_REGIME_API_BASE_URL"],
           let baseURL = URL(string: baseURLString) {
            service = RegimeAPIClient(baseURL: baseURL)
        } else {
            service = DemoRegimeService()
        }
    }

    var body: some View {
        DemoShellView(service: service)
            .padding(24)
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
