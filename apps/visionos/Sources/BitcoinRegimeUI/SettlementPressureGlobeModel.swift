import BitcoinRegimeDomain
import CoreGraphics
import SwiftUI
import simd

public enum SettlementPressureGlobeModel {
    public enum Accent: Int, CaseIterable, Hashable, Sendable {
        case cyan
        case mint
        case yellow
        case orange
        case red

        public var color: Color {
            switch self {
            case .cyan:
                return .cyan
            case .mint:
                return .mint
            case .yellow:
                return .yellow
            case .orange:
                return .orange
            case .red:
                return .red
            }
        }
    }

    public struct Hub: Identifiable, Hashable, Sendable {
        public let id: String
        public let name: String
        public let country: String
        public let region: String
        public let latitude: Double
        public let longitude: Double
        public let accent: Accent
        public let bias: Double
        public let role: String
        public let averageLatencyMs: Int
        public let peerCount: Int
        public let capacityGbps: Double
        public let operatorGroup: String

        public init(
            id: String,
            name: String,
            country: String,
            region: String,
            latitude: Double,
            longitude: Double,
            accent: Accent,
            bias: Double,
            role: String,
            averageLatencyMs: Int,
            peerCount: Int,
            capacityGbps: Double,
            operatorGroup: String
        ) {
            self.id = id
            self.name = name
            self.country = country
            self.region = region
            self.latitude = latitude
            self.longitude = longitude
            self.accent = accent
            self.bias = bias
            self.role = role
            self.averageLatencyMs = averageLatencyMs
            self.peerCount = peerCount
            self.capacityGbps = capacityGbps
            self.operatorGroup = operatorGroup
        }

        public var color: Color {
            accent.color
        }
    }

    public struct Route: Hashable, Sendable {
        public let from: Int
        public let to: Int
        public let bandIndex: Int
        public let emphasis: Double

        public init(from: Int, to: Int, bandIndex: Int, emphasis: Double) {
            self.from = from
            self.to = to
            self.bandIndex = bandIndex
            self.emphasis = emphasis
        }
    }

    public struct Coordinate: Hashable, Sendable {
        public let point: CGPoint
        public let depth: Double

        public init(point: CGPoint, depth: Double) {
            self.point = point
            self.depth = depth
        }
    }

    public struct Vector: Hashable, Sendable {
        public let x: Double
        public let y: Double
        public let z: Double

        public init(x: Double, y: Double, z: Double) {
            self.x = x
            self.y = y
            self.z = z
        }
    }

    public static let hubs: [Hub] = [
        Hub(
            id: "vancouver",
            name: "Vancouver",
            country: "Canada",
            region: "North America West",
            latitude: 49.28,
            longitude: -123.12,
            accent: .cyan,
            bias: 0.88,
            role: "Pacific ingress and miner-adjacent relay edge",
            averageLatencyMs: 28,
            peerCount: 182,
            capacityGbps: 7.2,
            operatorGroup: "Relay Pacific"
        ),
        Hub(
            id: "new-york",
            name: "New York",
            country: "United States",
            region: "North America East",
            latitude: 40.71,
            longitude: -74.00,
            accent: .mint,
            bias: 1.00,
            role: "Primary North Atlantic relay core",
            averageLatencyMs: 19,
            peerCount: 246,
            capacityGbps: 10.8,
            operatorGroup: "Atlas IX"
        ),
        Hub(
            id: "sao-paulo",
            name: "Sao Paulo",
            country: "Brazil",
            region: "South America",
            latitude: -23.55,
            longitude: -46.63,
            accent: .orange,
            bias: 0.72,
            role: "Southern hemisphere fee propagation hub",
            averageLatencyMs: 43,
            peerCount: 128,
            capacityGbps: 4.1,
            operatorGroup: "Sul Relay"
        ),
        Hub(
            id: "london",
            name: "London",
            country: "United Kingdom",
            region: "Western Europe",
            latitude: 51.50,
            longitude: -0.12,
            accent: .cyan,
            bias: 0.94,
            role: "Atlantic transit and policy relay exchange",
            averageLatencyMs: 17,
            peerCount: 214,
            capacityGbps: 8.4,
            operatorGroup: "Canary Mesh"
        ),
        Hub(
            id: "frankfurt",
            name: "Frankfurt",
            country: "Germany",
            region: "Central Europe",
            latitude: 50.11,
            longitude: 8.68,
            accent: .yellow,
            bias: 0.90,
            role: "EU settlement and exchange adjacency core",
            averageLatencyMs: 14,
            peerCount: 237,
            capacityGbps: 9.1,
            operatorGroup: "MainNet IX"
        ),
        Hub(
            id: "johannesburg",
            name: "Johannesburg",
            country: "South Africa",
            region: "Africa South",
            latitude: -26.20,
            longitude: 28.04,
            accent: .mint,
            bias: 0.58,
            role: "Regional failover and latency smoothing edge",
            averageLatencyMs: 51,
            peerCount: 104,
            capacityGbps: 3.2,
            operatorGroup: "Savanna Relay"
        ),
        Hub(
            id: "dubai",
            name: "Dubai",
            country: "UAE",
            region: "Middle East",
            latitude: 25.20,
            longitude: 55.27,
            accent: .orange,
            bias: 0.78,
            role: "Intercontinental routing and low-latency gateway",
            averageLatencyMs: 31,
            peerCount: 153,
            capacityGbps: 5.8,
            operatorGroup: "Gulf Stream IX"
        ),
        Hub(
            id: "singapore",
            name: "Singapore",
            country: "Singapore",
            region: "Southeast Asia",
            latitude: 1.35,
            longitude: 103.82,
            accent: .cyan,
            bias: 0.96,
            role: "APAC backbone relay and fee discovery nexus",
            averageLatencyMs: 16,
            peerCount: 228,
            capacityGbps: 9.7,
            operatorGroup: "Lion City Mesh"
        ),
        Hub(
            id: "tokyo",
            name: "Tokyo",
            country: "Japan",
            region: "North Asia",
            latitude: 35.68,
            longitude: 139.69,
            accent: .yellow,
            bias: 0.92,
            role: "High-frequency propagation and exchange hedging hub",
            averageLatencyMs: 18,
            peerCount: 211,
            capacityGbps: 8.9,
            operatorGroup: "Kanto Relay"
        ),
        Hub(
            id: "sydney",
            name: "Sydney",
            country: "Australia",
            region: "Oceania",
            latitude: -33.86,
            longitude: 151.21,
            accent: .mint,
            bias: 0.66,
            role: "Oceania distribution and resilience fallback edge",
            averageLatencyMs: 38,
            peerCount: 118,
            capacityGbps: 3.9,
            operatorGroup: "Harbour IX"
        )
    ]

    public static let routes: [Route] = [
        Route(from: 1, to: 3, bandIndex: 0, emphasis: 1.00),
        Route(from: 3, to: 4, bandIndex: 2, emphasis: 0.74),
        Route(from: 4, to: 7, bandIndex: 1, emphasis: 0.92),
        Route(from: 7, to: 8, bandIndex: 0, emphasis: 0.98),
        Route(from: 8, to: 9, bandIndex: 3, emphasis: 0.58),
        Route(from: 1, to: 2, bandIndex: 2, emphasis: 0.67),
        Route(from: 6, to: 7, bandIndex: 1, emphasis: 0.82),
        Route(from: 0, to: 8, bandIndex: 0, emphasis: 0.88)
    ]

    public static func weightedBandLoad(for route: Route, frame: ReplayFrame) -> Double {
        let queued = frame.feeBands.indices.contains(route.bandIndex)
            ? Double(frame.feeBands[route.bandIndex].queuedVBytes)
            : 0
        return queued * route.emphasis
    }

    public static func dominantBand(for hubIndex: Int, frame: ReplayFrame) -> FeeBand {
        let linkedRoutes = routes.filter { $0.from == hubIndex || $0.to == hubIndex }
        let chosenIndex = linkedRoutes
            .max(by: { weightedBandLoad(for: $0, frame: frame) < weightedBandLoad(for: $1, frame: frame) })?
            .bandIndex ?? 0

        return frame.feeBands.indices.contains(chosenIndex)
            ? frame.feeBands[chosenIndex]
            : FeeBand(label: "Base", minFee: 0, maxFee: 0, queuedVBytes: 0, estimatedBlocksToClear: 0)
    }

    public static func routeColor(for bandIndex: Int) -> Color {
        switch bandIndex {
        case 0:
            return .red
        case 1:
            return .orange
        case 2:
            return .yellow
        default:
            return .mint
        }
    }

    public static func vector(for hub: Hub) -> Vector {
        vector(latitude: hub.latitude, longitude: hub.longitude)
    }

    public static func vector(latitude: Double, longitude: Double) -> Vector {
        let lat = latitude * .pi / 180
        let lon = longitude * .pi / 180
        return Vector(
            x: cos(lat) * sin(lon),
            y: sin(lat),
            z: cos(lat) * cos(lon)
        )
    }

    public static func coordinate(latitude: Double, longitude: Double, rotation: Double) -> Coordinate {
        project(vector(latitude: latitude, longitude: longitude), rotation: rotation)
    }

    public static func project(_ vector: Vector, rotation: Double) -> Coordinate {
        let sinRotation = sin(rotation)
        let cosRotation = cos(rotation)
        let rotatedX = vector.x * cosRotation + vector.z * sinRotation
        let rotatedZ = vector.z * cosRotation - vector.x * sinRotation

        return Coordinate(
            point: CGPoint(x: CGFloat(rotatedX), y: CGFloat(vector.y)),
            depth: rotatedZ
        )
    }

    public static func midpointVector(from: Hub, to: Hub) -> Vector {
        normalize(
            Vector(
                x: vector(for: from).x + vector(for: to).x,
                y: vector(for: from).y + vector(for: to).y,
                z: vector(for: from).z + vector(for: to).z
            )
        )
    }

    public static func greatCircleVector(from: Hub, to: Hub, progress: Double) -> Vector {
        let clampedProgress = min(max(progress, 0), 1)
        let start = vector(for: from)
        let end = vector(for: to)
        let arc = acos(max(-1, min(1, dot(start, end))))

        guard arc > 0.0001 else {
            return end
        }

        let sinArc = sin(arc)
        let fromWeight = sin((1 - clampedProgress) * arc) / sinArc
        let toWeight = sin(clampedProgress * arc) / sinArc

        return normalize(
            Vector(
                x: start.x * fromWeight + end.x * toWeight,
                y: start.y * fromWeight + end.y * toWeight,
                z: start.z * fromWeight + end.z * toWeight
            )
        )
    }

    public static func greatCircleVectors(from: Hub, to: Hub, steps: Int = 48) -> [Vector] {
        (0...max(steps, 1)).map { step in
            let progress = Double(step) / Double(max(steps, 1))
            return greatCircleVector(from: from, to: to, progress: progress)
        }
    }

    public static func greatCircleCoordinates(
        from: Hub,
        to: Hub,
        rotation: Double,
        steps: Int = 48
    ) -> [Coordinate] {
        greatCircleVectors(from: from, to: to, steps: steps).map {
            project($0, rotation: rotation)
        }
    }

    public static func position(for hub: Hub, radius: Float) -> SIMD3<Float> {
        position(for: vector(for: hub), radius: radius)
    }

    public static func position(for vector: Vector, radius: Float) -> SIMD3<Float> {
        SIMD3<Float>(
            radius * Float(vector.x),
            radius * Float(vector.y),
            radius * Float(vector.z)
        )
    }

    public static func normalize(_ vector: Vector) -> Vector {
        let length = sqrt((vector.x * vector.x) + (vector.y * vector.y) + (vector.z * vector.z))
        guard length > 0 else {
            return vector
        }

        return Vector(
            x: vector.x / length,
            y: vector.y / length,
            z: vector.z / length
        )
    }

    public static func dot(_ lhs: Vector, _ rhs: Vector) -> Double {
        (lhs.x * rhs.x) + (lhs.y * rhs.y) + (lhs.z * rhs.z)
    }
}
