import Foundation

public enum BitcoinRegimeSharedStorage {
    public static let appGroupIdentifier = "group.com.black77dragon.BitcoinRegimeNavigator"
    public static let widgetCacheDirectoryName = "WidgetCache"
    public static let widgetSnapshotFileName = "current-snapshot.json"

    public static func widgetCacheDirectoryURL(
        fileManager: FileManager = .default,
        appGroupIdentifier: String = appGroupIdentifier,
        containerURLResolver: @Sendable (FileManager, String) -> URL? = defaultContainerURLResolver
    ) -> URL? {
        guard let containerURL = containerURLResolver(
            fileManager,
            appGroupIdentifier
        ) else {
            return nil
        }

        return containerURL.appending(path: widgetCacheDirectoryName, directoryHint: .isDirectory)
    }

    public static let defaultContainerURLResolver: @Sendable (FileManager, String) -> URL? = { fileManager, appGroupIdentifier in
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
}

public struct WidgetSnapshotCache {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let appGroupIdentifier: String
    private let containerURLResolver: @Sendable (FileManager, String) -> URL?

    public init(
        fileManager: FileManager = .default,
        encoder: JSONEncoder = .bitcoinRegimeEncoder(),
        decoder: JSONDecoder = .bitcoinRegimeDecoder(),
        appGroupIdentifier: String = BitcoinRegimeSharedStorage.appGroupIdentifier,
        containerURLResolver: @escaping @Sendable (FileManager, String) -> URL? = BitcoinRegimeSharedStorage.defaultContainerURLResolver
    ) {
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
        self.appGroupIdentifier = appGroupIdentifier
        self.containerURLResolver = containerURLResolver
    }

    public func save(snapshot: RegimeSnapshot, now: Date = Date()) throws -> URL? {
        guard let fileURL = snapshotFileURL() else {
            return nil
        }

        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let export = SnapshotExport(savedAt: now, snapshot: snapshot)
        let data = try encoder.encode(export)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    public func loadLatest() throws -> SnapshotExport? {
        guard let fileURL = snapshotFileURL(), fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(SnapshotExport.self, from: data)
    }

    public func snapshotFileURL() -> URL? {
        BitcoinRegimeSharedStorage.widgetCacheDirectoryURL(
            fileManager: fileManager,
            appGroupIdentifier: appGroupIdentifier,
            containerURLResolver: containerURLResolver
        )?.appending(path: BitcoinRegimeSharedStorage.widgetSnapshotFileName)
    }
}
