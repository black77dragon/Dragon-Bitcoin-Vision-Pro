import Foundation

public final class SnapshotStore: @unchecked Sendable {
    public enum SnapshotStoreError: Error {
        case missingDirectory
    }

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        directory: URL? = nil,
        encoder: JSONEncoder = .bitcoinRegimeEncoder(),
        decoder: JSONDecoder = .bitcoinRegimeDecoder()
    ) throws {
        if let directory {
            self.directory = directory
        } else {
            guard let defaultDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw SnapshotStoreError.missingDirectory
            }
            self.directory = defaultDirectory.appending(path: "BitcoinRegimeNavigator", directoryHint: .isDirectory)
        }

        self.encoder = encoder
        self.decoder = decoder
        try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    public func save(snapshot: RegimeSnapshot, name: String? = nil) throws -> URL {
        let export = SnapshotExport(savedAt: Date(), snapshot: snapshot)
        let data = try encoder.encode(export)
        let fileName = name ?? "snapshot-\(Int(export.savedAt.timeIntervalSince1970)).json"
        let fileURL = directory.appending(path: fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    public func loadAll() throws -> [SnapshotExport] {
        let fileURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted(by: { $0.lastPathComponent > $1.lastPathComponent })

        return try fileURLs.map { url in
            let data = try Data(contentsOf: url)
            return try decoder.decode(SnapshotExport.self, from: data)
        }
    }
}
