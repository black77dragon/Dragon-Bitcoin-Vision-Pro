import Foundation
import Testing
@testable import BitcoinRegimeDomain

@Test func demoSnapshotIncludesThreeScores() async throws {
    let service = DemoRegimeService()
    let snapshot = try await service.fetchCurrentBriefing()

    #expect(snapshot.scores.count == 3)
    #expect(snapshot.evidence.count == 3)
    #expect(snapshot.marketWeather?.components.count == 4)
    #expect(snapshot.btcPrice?.priceUsd ?? 0 > 0)
    #expect(snapshot.regime.key == .elevatedNetworkStress)
}

@Test func replayContainsClearanceEvents() async throws {
    let timeline = BitcoinRegimeSampleData.replay(range: .sixHours, bucket: .oneMinute)
    let clearanceEvents = timeline.frames.compactMap(\.blockClearance)

    #expect(!clearanceEvents.isEmpty)
    #expect(timeline.frames.count >= 300)
}

@Test func snapshotStoreRoundTripsSavedSnapshots() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let store = try SnapshotStore(directory: tempDirectory)
    let snapshot = BitcoinRegimeSampleData.snapshot()

    _ = try store.save(snapshot: snapshot, name: "demo.json")
    let saved = try store.loadAll()

    #expect(saved.count == 1)
    #expect(saved.first?.snapshot.regime.label == snapshot.regime.label)
}

@Test func fallbackServiceUsesDemoDataWhenPrimaryFails() async throws {
    let service = FallbackRegimeService(primary: ThrowingRegimeService())

    let snapshot = try await service.fetchCurrentBriefing()
    let replay = try await service.fetchReplay(range: .sixHours, bucket: .oneMinute)
    let methodology = try await service.fetchMethodology()

    #expect(snapshot.sources.contains(where: { $0.status == .demo }))
    #expect(!replay.frames.isEmpty)
    #expect(!methodology.limitations.isEmpty)
}

@Test func apiClientBuildsRelativeURLsWithoutEncodingQueryDelimiters() throws {
    let client = RegimeAPIClient(baseURL: URL(string: "http://127.0.0.1:8787")!)

    let briefingURL = try client.makeURL(path: "/v1/briefing/current?mode=auto")
    let replayURL = try client.makeURL(path: "/v1/mempool/replay?range=6h&bucket=1m&mode=auto")
    let methodologyURL = try client.makeURL(path: "/v1/methodology")

    #expect(briefingURL.absoluteString == "http://127.0.0.1:8787/v1/briefing/current?mode=auto")
    #expect(replayURL.absoluteString == "http://127.0.0.1:8787/v1/mempool/replay?range=6h&bucket=1m&mode=auto")
    #expect(methodologyURL.absoluteString == "http://127.0.0.1:8787/v1/methodology")
}

private struct ThrowingRegimeService: RegimeService {
    func fetchCurrentBriefing() async throws -> RegimeSnapshot {
        throw URLError(.badServerResponse)
    }

    func fetchReplay(range: ReplayRange, bucket: ReplayBucket) async throws -> ReplayTimeline {
        throw URLError(.badServerResponse)
    }

    func fetchMethodology() async throws -> MethodologyResponse {
        throw URLError(.badServerResponse)
    }
}
