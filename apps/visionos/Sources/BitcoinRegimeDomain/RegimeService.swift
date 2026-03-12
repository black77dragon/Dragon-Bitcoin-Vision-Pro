import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol RegimeService: Sendable {
    func fetchCurrentBriefing() async throws -> RegimeSnapshot
    func fetchReplay(range: ReplayRange, bucket: ReplayBucket) async throws -> ReplayTimeline
    func fetchMethodology() async throws -> MethodologyResponse
}

public struct DemoRegimeService: RegimeService {
    public init() {}

    public func fetchCurrentBriefing() async throws -> RegimeSnapshot {
        BitcoinRegimeSampleData.snapshot()
    }

    public func fetchReplay(range: ReplayRange, bucket: ReplayBucket) async throws -> ReplayTimeline {
        BitcoinRegimeSampleData.replay(range: range, bucket: bucket)
    }

    public func fetchMethodology() async throws -> MethodologyResponse {
        BitcoinRegimeSampleData.methodology()
    }
}

public struct FallbackRegimeService: RegimeService {
    public let primary: any RegimeService
    public let fallback: any RegimeService

    public init(
        primary: any RegimeService,
        fallback: any RegimeService = DemoRegimeService()
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    public func fetchCurrentBriefing() async throws -> RegimeSnapshot {
        do {
            return try await primary.fetchCurrentBriefing()
        } catch {
            return try await fallback.fetchCurrentBriefing()
        }
    }

    public func fetchReplay(range: ReplayRange, bucket: ReplayBucket) async throws -> ReplayTimeline {
        do {
            return try await primary.fetchReplay(range: range, bucket: bucket)
        } catch {
            return try await fallback.fetchReplay(range: range, bucket: bucket)
        }
    }

    public func fetchMethodology() async throws -> MethodologyResponse {
        do {
            return try await primary.fetchMethodology()
        } catch {
            return try await fallback.fetchMethodology()
        }
    }
}

public struct RegimeAPIClient: RegimeService {
    public let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = .bitcoinRegimeDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }

    public func fetchCurrentBriefing() async throws -> RegimeSnapshot {
        try await request(path: "/v1/briefing/current?mode=auto")
    }

    public func fetchReplay(range: ReplayRange, bucket: ReplayBucket) async throws -> ReplayTimeline {
        try await request(path: "/v1/mempool/replay?range=\(range.rawValue)&bucket=\(bucket.rawValue)&mode=auto")
    }

    public func fetchMethodology() async throws -> MethodologyResponse {
        try await request(path: "/v1/methodology")
    }

    private func request<Response: Decodable>(path: String) async throws -> Response {
        let url = try makeURL(path: path)
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try decoder.decode(Response.self, from: data)
    }

    func makeURL(path: String) throws -> URL {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw URLError(.badURL)
        }

        return url
    }
}
