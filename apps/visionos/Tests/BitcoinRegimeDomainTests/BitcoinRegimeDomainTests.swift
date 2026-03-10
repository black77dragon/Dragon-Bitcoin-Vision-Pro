import BitcoinRegimeDomain
import Foundation
import Testing

@Test func demoSnapshotIncludesThreeScores() async throws {
    let service = DemoRegimeService()
    let snapshot = try await service.fetchCurrentBriefing()

    #expect(snapshot.scores.count == 3)
    #expect(snapshot.evidence.count == 3)
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
