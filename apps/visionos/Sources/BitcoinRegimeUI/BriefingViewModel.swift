import BitcoinRegimeDomain
import Foundation
import SwiftUI

@MainActor
public final class BriefingViewModel: ObservableObject {
    @Published public private(set) var snapshot: RegimeSnapshot?
    @Published public private(set) var replay: ReplayTimeline?
    @Published public private(set) var methodology: MethodologyResponse?
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private let service: any RegimeService

    public init(service: any RegimeService = DemoRegimeService()) {
        self.service = service
    }

    public func load() async {
        isLoading = true
        errorMessage = nil

        do {
            async let snapshot = service.fetchCurrentBriefing()
            async let replay = service.fetchReplay(range: .sixHours, bucket: .oneMinute)
            async let methodology = service.fetchMethodology()

            self.snapshot = try await snapshot
            self.replay = try await replay
            self.methodology = try await methodology
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
