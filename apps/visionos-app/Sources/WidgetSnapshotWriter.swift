import BitcoinRegimeDomain
import Foundation

enum WidgetSnapshotWriter {
    static func save(snapshot: RegimeSnapshot) {
        Task.detached(priority: .utility) {
            do {
                _ = try WidgetSnapshotCache().save(snapshot: snapshot)
            } catch {
                #if DEBUG
                print("Failed to cache widget snapshot: \(error)")
                #endif
            }
        }
    }
}
