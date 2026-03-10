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
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    AppChromeHeader()
                    DemoShellView(service: service)
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
}

private struct AppChromeHeader: View {
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Bitcoin Regime Navigator")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Vision Pro MVP")
                    .font(.headline)
                    .foregroundStyle(Color.white.opacity(0.78))
                Text("Detect and explain the current Bitcoin regime in under 60 seconds.")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.64))
            }

            Spacer()

            Text("Internal Prototype")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.78))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.10), in: Capsule())
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}
