import BitcoinRegimeDomain
import SwiftUI

public struct NetworkTrafficGlobeWindowView: View {
    public let timeline: ReplayTimeline
    @State private var activeIndex: Int = 0
    @State private var isPlaying = false
    @State private var playbackStep: Int = 0
    @State private var playbackSpeed: ReplayPlaybackSpeed = .normal

    public init(timeline: ReplayTimeline) {
        self.timeline = timeline
        let initialIndex = max(timeline.frames.count - 1, 0)
        _activeIndex = State(initialValue: initialIndex)
        _playbackStep = State(initialValue: initialIndex)
    }

    public var body: some View {
        let scene = LiveTrafficScene(
            timeline: timeline,
            activeIndex: activeIndex,
            phase: Double(playbackStep)
        )
        let replayState = TileDeliveryState.from(source: timeline.source)

        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                header(scene: scene, replayState: replayState)

                HStack(alignment: .top, spacing: 24) {
                    GlobePanel(scene: scene, status: .mockup)
                        .frame(maxWidth: .infinity, minHeight: 640)

                    VStack(spacing: 16) {
                        ActionNavigatorPanel(scene: scene, status: replayState)
                        WatchpointPanel(scene: scene, status: .mockup)
                        ExecutionPlannerPanel(scene: scene, status: replayState)
                    }
                    .frame(width: 360)
                }

                TrafficSurfacePanel(scene: scene, status: replayState)
                    .frame(height: 260)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.visible, axes: .vertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.05, blue: 0.11),
                        Color(red: 0.06, green: 0.09, blue: 0.19),
                        Color(red: 0.02, green: 0.08, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Color.cyan.opacity(0.18),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: 500
                )
            }
        )
        .ignoresSafeArea()
        .task(id: isPlaying ? playbackSpeed : nil) {
            guard isPlaying, timeline.frames.count > 1 else {
                return
            }

            if activeIndex >= timeline.frames.count - 1 {
                activeIndex = 0
                playbackStep = 0
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: playbackSpeed.interval)

                guard !Task.isCancelled else {
                    break
                }

                playbackStep += 1
                activeIndex = nextPlaybackIndex(after: activeIndex)
            }
        }
        .onChange(of: timeline.frames.count) { _, frameCount in
            if frameCount < 2 {
                isPlaying = false
            }

            activeIndex = min(max(activeIndex, 0), max(frameCount - 1, 0))
            playbackStep = max(playbackStep, activeIndex)
        }
    }

    @ViewBuilder
    private func header(scene: LiveTrafficScene, replayState: TileDeliveryState) -> some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("Global Fee Pressure Navigator")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    TileStatusBadge(state: replayState)
                }

                Text(scene.activeFrame.stateLabel)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Text(isPlaying
                     ? "The replay is stepping through settlement pressure so you can see whether congestion is spreading, clearing, or refilling."
                     : "Use this view to answer one question quickly: should you send now, wait for the next clearance, or pay into a higher fee lane?")
                    .font(.body)
                    .foregroundStyle(Color.white.opacity(0.72))

                Text("The globe is an inferred relay-pressure map built from the replay. It is useful for spotting where fee pressure concentrates before you choose a send strategy.")
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.58))

                Text("Source: \(timeline.source.name)")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.62))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                ReplayTransportBar(
                    isPlaying: isPlaying,
                    canInteract: timeline.frames.count > 1,
                    stageLabel: stageLabel,
                    timestamp: scene.activeFrame.timestamp,
                    speed: playbackSpeed,
                    controlSize: .regular,
                    theme: .lightPanel,
                    onTogglePlayback: togglePlayback,
                    onStopPlayback: stopPlayback,
                    onChangeSpeed: { playbackSpeed = $0 }
                )
            }
        }
        .padding(22)
        .background(panelBackground)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }

    private var stageLabel: String {
        let total = max(timeline.frames.count, 1)
        let current = min(max(activeIndex + 1, 1), total)
        return "Stage \(current) of \(total)"
    }

    private func togglePlayback() {
        guard timeline.frames.count > 1 else {
            return
        }

        if !isPlaying, activeIndex >= timeline.frames.count - 1 {
            activeIndex = 0
            playbackStep = 0
        }

        isPlaying.toggle()
    }

    private func stopPlayback() {
        isPlaying = false
        activeIndex = 0
        playbackStep = 0
    }

    private func nextPlaybackIndex(after currentIndex: Int) -> Int {
        guard timeline.frames.count > 1 else {
            return 0
        }

        return (currentIndex + 1) % timeline.frames.count
    }
}

private struct GlobePanel: View {
    let scene: LiveTrafficScene
    let status: TileDeliveryState
    @State private var settledRotation: Double = 0
    @State private var dragOriginRotation: Double?
    @State private var focusedHubID: String?
    @State private var sortMode: ConnectionSortMode = .relayShare
    @State private var sortAscending = false

    var body: some View {
        let projection = scene.globeProjection(rotationOffset: settledRotation)
        let focusedHub = focusedHubID.flatMap { id in
            projection.nodes.first(where: { $0.id == id })
        }

        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text("Settlement Pressure Globe")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        TileStatusBadge(state: status)
                    }
                    Text("Drag to inspect where the replay suggests fee pressure is concentrating. Select a hub to see what that hotspot means for transaction timing and cost.")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.68))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(projection.visibleNodeCount) hubs visible")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.62))
                    VStack(alignment: .trailing, spacing: 4) {
                        Label("Drag to rotate", systemImage: "hand.draw")
                        Label("Click on a hub for details", systemImage: "cursorarrow.click")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.cyan.opacity(0.85))
                }
            }

            GeometryReader { geometry in
                HStack(alignment: .top, spacing: 18) {
                    GeometryReader { globeGeometry in
                        let layout = GlobeLayout(size: globeGeometry.size)

                        ZStack {
                            Canvas(rendersAsynchronously: true) { context, _ in
                                drawGlobe(
                                    context: &context,
                                    layout: layout,
                                    projection: projection,
                                    focusedHubID: focusedHubID
                                )
                            }

                            ForEach(projection.nodes.filter { $0.depth > -0.10 }) { hub in
                                HubCallout(
                                    hub: hub,
                                    isSelected: focusedHubID == hub.id,
                                    layoutDirection: hub.point.x >= 0 ? .trailing : .leading
                                ) {
                                    focusedHubID = hub.id
                                }
                                .position(layout.calloutPoint(for: hub))
                            }

                            if let focusedHub {
                                HubFocusCard(hub: focusedHub) {
                                    focusedHubID = nil
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                .padding(20)
                            }

                            HStack(spacing: 12) {
                                GlobeStatChip(title: "Best Move", value: scene.actionRecommendation.badge, tint: scene.actionRecommendation.tint)
                                GlobeStatChip(title: "Relief", value: scene.nextReliefShortLabel, tint: .mint)
                                GlobeStatChip(title: "Hot Path", value: scene.primaryRouteCode, tint: .orange)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .simultaneousGesture(rotationGesture)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ConnectionListPanel(
                        hubs: sortedHubs(from: projection.nodes),
                        focusedHubID: focusedHubID,
                        sortMode: sortMode,
                        sortAscending: sortAscending,
                        onSort: updateSort,
                        onSelect: { focusedHubID = $0 }
                    )
                    .frame(width: 290)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            }
            .frame(minHeight: 560, idealHeight: 620, alignment: .topLeading)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private var rotationGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if dragOriginRotation == nil {
                    dragOriginRotation = settledRotation
                }

                settledRotation = (dragOriginRotation ?? 0) + Double(value.translation.width) * 0.01
            }
            .onEnded { value in
                settledRotation = (dragOriginRotation ?? settledRotation) + Double(value.translation.width) * 0.01
                dragOriginRotation = nil
            }
    }

    private func updateSort(_ selectedMode: ConnectionSortMode) {
        if sortMode == selectedMode {
            sortAscending.toggle()
            return
        }

        sortMode = selectedMode
        sortAscending = selectedMode == .city
    }

    private func sortedHubs(from hubs: [ProjectedHub]) -> [ProjectedHub] {
        hubs.sorted { lhs, rhs in
            switch sortMode {
            case .city:
                let comparison = lhs.hub.name.localizedCaseInsensitiveCompare(rhs.hub.name)
                if comparison == .orderedSame {
                    return sortAscending ? lhs.id < rhs.id : lhs.id > rhs.id
                }
                return sortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
            case .relayShare:
                if lhs.liveStatus.relayShare == rhs.liveStatus.relayShare {
                    return sortAscending
                        ? lhs.hub.name.localizedCaseInsensitiveCompare(rhs.hub.name) == .orderedAscending
                        : lhs.hub.name.localizedCaseInsensitiveCompare(rhs.hub.name) == .orderedDescending
                }
                return sortAscending
                    ? lhs.liveStatus.relayShare < rhs.liveStatus.relayShare
                    : lhs.liveStatus.relayShare > rhs.liveStatus.relayShare
            case .latency:
                if lhs.liveStatus.latencyMs == rhs.liveStatus.latencyMs {
                    return sortAscending
                        ? lhs.hub.name.localizedCaseInsensitiveCompare(rhs.hub.name) == .orderedAscending
                        : lhs.hub.name.localizedCaseInsensitiveCompare(rhs.hub.name) == .orderedDescending
                }
                return sortAscending
                    ? lhs.liveStatus.latencyMs < rhs.liveStatus.latencyMs
                    : lhs.liveStatus.latencyMs > rhs.liveStatus.latencyMs
            }
        }
    }

    private func drawGlobe(
        context: inout GraphicsContext,
        layout: GlobeLayout,
        projection: GlobeProjection,
        focusedHubID: String?
    ) {
        let globePath = Path(ellipseIn: layout.sphereRect)

        context.fill(
            globePath,
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.17, green: 0.56, blue: 0.76),
                    Color(red: 0.06, green: 0.18, blue: 0.38),
                    Color(red: 0.01, green: 0.03, blue: 0.09)
                ]),
                center: CGPoint(x: layout.center.x - layout.radius * 0.18, y: layout.center.y - layout.radius * 0.28),
                startRadius: layout.radius * 0.05,
                endRadius: layout.radius * 1.12
            )
        )

        context.fill(
            globePath,
            with: .linearGradient(
                Gradient(colors: [
                    Color.white.opacity(0.16),
                    .clear,
                    Color.black.opacity(0.26)
                ]),
                startPoint: CGPoint(x: layout.center.x - layout.radius, y: layout.center.y - layout.radius * 0.8),
                endPoint: CGPoint(x: layout.center.x + layout.radius, y: layout.center.y + layout.radius * 0.9)
            )
        )

        let haloRect = layout.sphereRect.insetBy(dx: -26, dy: -26)
        context.stroke(
            Path(ellipseIn: haloRect),
            with: .color(Color.cyan.opacity(0.15)),
            lineWidth: 16
        )

        drawPolarCaps(context: &context, layout: layout)
        drawLandmasses(context: &context, layout: layout, rotation: projection.rotation)

        for latitude in stride(from: -60.0, through: 60.0, by: 30.0) {
            context.stroke(
                graticulePath(
                    center: layout.center,
                    radius: layout.radius,
                    rotation: projection.rotation,
                    fixedLatitude: latitude
                ),
                with: .color(Color.white.opacity(0.08)),
                lineWidth: 0.8
            )
        }

        for longitude in stride(from: -150.0, through: 180.0, by: 30.0) {
            context.stroke(
                graticulePath(
                    center: layout.center,
                    radius: layout.radius,
                    rotation: projection.rotation,
                    fixedLongitude: longitude
                ),
                with: .color(Color.white.opacity(0.07)),
                lineWidth: 0.7
            )
        }

        for route in projection.routes {
            let path = surfaceRoutePath(
                from: route.from.hub,
                to: route.to.hub,
                rotation: projection.rotation,
                layout: layout
            )

            context.stroke(
                path,
                with: .color(route.color.opacity(route.opacity)),
                style: StrokeStyle(lineWidth: route.lineWidth, lineCap: .round)
            )
        }

        for hub in projection.nodes.sorted(by: { $0.depth < $1.depth }) {
            guard hub.depth > -0.28 else {
                continue
            }

            let hubPoint = layout.screenPoint(for: hub.point)
            let haloSize = hub.radius * 4.8
            let haloRect = CGRect(
                x: hubPoint.x - haloSize / 2,
                y: hubPoint.y - haloSize / 2,
                width: haloSize,
                height: haloSize
            )

            context.fill(
                Path(ellipseIn: haloRect),
                with: .radialGradient(
                    Gradient(colors: [hub.color.opacity(0.34), .clear]),
                    center: hubPoint,
                    startRadius: 0,
                    endRadius: haloSize / 2
                )
            )

            let ringSize = hub.radius + (focusedHubID == hub.id ? 9 : 5)
            let ringRect = CGRect(
                x: hubPoint.x - ringSize / 2,
                y: hubPoint.y - ringSize / 2,
                width: ringSize,
                height: ringSize
            )
            context.stroke(
                Path(ellipseIn: ringRect),
                with: .color(Color.white.opacity(focusedHubID == hub.id ? 0.78 : 0.34)),
                lineWidth: focusedHubID == hub.id ? 1.6 : 0.9
            )

            let hubRect = CGRect(
                x: hubPoint.x - hub.radius / 2,
                y: hubPoint.y - hub.radius / 2,
                width: hub.radius,
                height: hub.radius
            )
            context.fill(Path(ellipseIn: hubRect), with: .color(hub.color))
        }

        context.stroke(
            globePath,
            with: .color(Color.white.opacity(0.18)),
            lineWidth: 1.2
        )
    }

    private func drawPolarCaps(context: inout GraphicsContext, layout: GlobeLayout) {
        let northCap = CGRect(
            x: layout.center.x - layout.radius * 0.32,
            y: layout.center.y - layout.radius * 0.94,
            width: layout.radius * 0.64,
            height: layout.radius * 0.34
        )
        let southCap = CGRect(
            x: layout.center.x - layout.radius * 0.36,
            y: layout.center.y + layout.radius * 0.60,
            width: layout.radius * 0.72,
            height: layout.radius * 0.22
        )

        context.fill(Path(ellipseIn: northCap), with: .color(Color.white.opacity(0.16)))
        context.fill(Path(ellipseIn: southCap), with: .color(Color.white.opacity(0.12)))
    }

    private func drawLandmasses(
        context: inout GraphicsContext,
        layout: GlobeLayout,
        rotation: Double
    ) {
        for row in sourcedLandRows {
            for longitude in row.longitudes {
                let coordinate = globeCoordinate(latitude: row.latitude, longitude: longitude, rotation: rotation)
                guard coordinate.depth > 0.02 else {
                    continue
                }

                let point = layout.screenPoint(for: coordinate.point)
                let size = max(2.6, CGFloat(coordinate.depth) * 5.8)
                let landRect = CGRect(
                    x: point.x - size / 2,
                    y: point.y - size / 2,
                    width: size,
                    height: size
                )

                let seed = (sin(row.latitude * .pi / 9) + cos(longitude * .pi / 12)) * 0.5
                let landBase = seed > 0
                    ? Color(red: 0.26, green: 0.63, blue: 0.43)
                    : Color(red: 0.19, green: 0.50, blue: 0.35)
                let coastHighlight = Color(red: 0.69, green: 0.89, blue: 0.77)

                context.fill(
                    Path(ellipseIn: landRect.insetBy(dx: -0.5, dy: -0.5)),
                    with: .color(landBase.opacity(0.20 + coordinate.depth * 0.26))
                )

                context.fill(
                    Path(ellipseIn: landRect),
                    with: .color(landBase.opacity(0.44 + coordinate.depth * 0.34))
                )
                context.fill(
                    Path(ellipseIn: landRect.insetBy(dx: size * 0.18, dy: size * 0.18)),
                    with: .color(coastHighlight.opacity(0.10 + coordinate.depth * 0.12))
                )
            }
        }
    }
}

private enum ConnectionSortMode {
    case city
    case relayShare
    case latency
}

private struct HubCallout: View {
    let hub: ProjectedHub
    let isSelected: Bool
    let layoutDirection: HorizontalAlignment
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: layoutDirection, spacing: 4) {
                Text(hub.hub.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(Int(hub.liveStatus.relayShare * 100))% relay  •  \(hub.liveStatus.latencyLabel)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(hub.color.opacity(0.96))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(calloutBackground)
        }
        .buttonStyle(.plain)
    }

    private var calloutBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.black.opacity(isSelected ? 0.44 : 0.28))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke((isSelected ? hub.color : Color.white).opacity(isSelected ? 0.75 : 0.16), lineWidth: 1)
            )
    }
}

private struct ConnectionListPanel: View {
    let hubs: [ProjectedHub]
    let focusedHubID: String?
    let sortMode: ConnectionSortMode
    let sortAscending: Bool
    let onSort: (ConnectionSortMode) -> Void
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Hubs")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(hubs.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.60))
            }

            HStack(spacing: 10) {
                SortButton(
                    title: "City",
                    isActive: sortMode == .city,
                    isAscending: sortAscending
                ) {
                    onSort(.city)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                SortButton(
                    title: "Relay %",
                    isActive: sortMode == .relayShare,
                    isAscending: sortAscending
                ) {
                    onSort(.relayShare)
                }
                .frame(width: 72, alignment: .trailing)

                SortButton(
                    title: "MS",
                    isActive: sortMode == .latency,
                    isAscending: sortAscending
                ) {
                    onSort(.latency)
                }
                .frame(width: 52, alignment: .trailing)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(hubs) { hub in
                        Button {
                            onSelect(hub.id)
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(hub.color)
                                    .frame(width: 10, height: 10)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(hub.hub.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(hub.hub.region)
                                        .font(.caption)
                                        .foregroundStyle(Color.white.opacity(0.54))
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 8)

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(Int(hub.liveStatus.relayShare * 100))%")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(hub.color)
                                    Text("\(hub.liveStatus.latencyMs) ms")
                                        .font(.caption2.monospacedDigit().weight(.semibold))
                                        .foregroundStyle(Color.white.opacity(0.72))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(rowBackground(for: hub))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func rowBackground(for hub: ProjectedHub) -> some View {
        let isSelected = focusedHubID == hub.id
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(isSelected ? hub.color.opacity(0.18) : Color.black.opacity(0.16))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke((isSelected ? hub.color : Color.white).opacity(isSelected ? 0.48 : 0.08), lineWidth: 1)
            )
    }
}

private struct SortButton: View {
    let title: String
    let isActive: Bool
    let isAscending: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                if isActive {
                    Image(systemName: isAscending ? "arrow.up" : "arrow.down")
                        .font(.caption2.weight(.bold))
                }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(isActive ? Color.cyan.opacity(0.92) : Color.white.opacity(0.58))
        }
        .buttonStyle(.plain)
    }
}

private struct HubFocusCard: View {
    let hub: ProjectedHub
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(hub.hub.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("\(hub.hub.region) • \(hub.hub.country)")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.74))
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Text(hub.liveStatus.status.uppercased())
                .font(.caption.weight(.black))
                .foregroundStyle(hub.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(hub.color.opacity(0.16), in: Capsule())

            Text(hub.hub.role)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)

            Text(hub.settlementImpactSummary)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.72))

            VStack(spacing: 10) {
                HubSpecRow(label: "Settlement impact", value: hub.liveStatus.executionTone)
                HubSpecRow(label: "Relay share", value: "\(Int(hub.liveStatus.relayShare * 100))%")
                HubSpecRow(label: "Throughput", value: "\(hub.liveStatus.throughput) handoffs/min")
                HubSpecRow(label: "Primary lane", value: hub.liveStatus.lane.label)
                HubSpecRow(label: "Hub queue", value: hub.liveStatus.queueLabel)
                HubSpecRow(label: "Median latency", value: hub.liveStatus.latencyLabel)
                HubSpecRow(label: "Connected peers", value: "\(hub.hub.peerCount)")
                HubSpecRow(label: "Operator", value: hub.hub.operatorGroup)
                HubSpecRow(label: "Capacity", value: String(format: "%.1f Gbps", hub.hub.capacityGbps))
                HubSpecRow(label: "Observed uptime", value: hub.liveStatus.uptimeLabel)
            }
        }
        .padding(20)
        .frame(width: 320, alignment: .leading)
        .background(glassBackground)
        .shadow(color: Color.black.opacity(0.28), radius: 24, y: 10)
    }

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color.white.opacity(0.04),
                        Color.cyan.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
    }
}

private struct HubSpecRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.60))
            Spacer()
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
    }
}

private struct GlobeStatChip: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.52))
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(tint.opacity(0.14))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.35), lineWidth: 1)
                )
        )
    }
}

private struct ActionNavigatorPanel: View {
    let scene: LiveTrafficScene
    let status: TileDeliveryState

    var body: some View {
        let recommendation = scene.actionRecommendation

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Decision Guide")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                TileStatusBadge(state: status)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(recommendation.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text(recommendation.summary)
                            .font(.footnote)
                            .foregroundStyle(Color.white.opacity(0.72))
                    }

                    Spacer(minLength: 0)

                    Text(recommendation.badge)
                        .font(.caption.weight(.black))
                        .foregroundStyle(recommendation.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(recommendation.tint.opacity(0.14), in: Capsule())
                }

                Text(recommendation.nextStep)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(recommendation.tint.opacity(0.94))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.18))
            )

            HStack(spacing: 10) {
                MetricTile(title: "Recommended lane", value: scene.recommendedBand.label, detail: scene.recommendedBandFeeLabel, tint: recommendation.tint)
                MetricTile(title: "Next relief", value: scene.nextReliefShortLabel, detail: scene.nextReliefDetail, tint: .mint)
            }

            HStack(spacing: 10) {
                MetricTile(title: "Queue drift", value: scene.queueDriftLabel, detail: scene.momentumDetail, tint: scene.queueDriftTint)
                MetricTile(title: "Dominant pressure", value: scene.dominantBand.label, detail: scene.primaryRouteLabel, tint: .orange)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.62))
            Text(value)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(detail)
                .font(.caption)
                .foregroundStyle(tint.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }
}

private struct WatchpointPanel: View {
    let scene: LiveTrafficScene
    let status: TileDeliveryState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Watchpoints")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                TileStatusBadge(state: status)
            }

            Text("These hubs are where the replay says pressure is most likely to tighten first. Use them as an operator-facing signal, not literal node telemetry.")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.62))

            ForEach(scene.watchpoints) { watchpoint in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(watchpoint.tint)
                        .frame(width: 10, height: 10)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(watchpoint.label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(watchpoint.tone)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(watchpoint.tint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(watchpoint.tint.opacity(0.12), in: Capsule())
                        }
                        Text(watchpoint.subtitle)
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.58))
                        Text(watchpoint.impact)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.84))
                    }

                    Spacer()

                    Text(watchpoint.loadLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(watchpoint.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(watchpoint.tint.opacity(0.14), in: Capsule())
                }
                .padding(.vertical, 4)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

private struct ExecutionPlannerPanel: View {
    let scene: LiveTrafficScene
    let status: TileDeliveryState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Execution Plan")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                TileStatusBadge(state: status)
            }

            Text("Each lane shows the likely fee tier and clearance pace implied by the current replay frame.")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.62))

            ForEach(scene.executionPlans) { plan in
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(plan.tint)
                        .frame(width: 5, height: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(plan.label)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            if plan.isRecommended {
                                Text("Best fit")
                                    .font(.caption2.weight(.black))
                                    .foregroundStyle(plan.tint)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(plan.tint.opacity(0.14), in: Capsule())
                            }
                        }
                        Text(plan.detail)
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.60))
                        Text(plan.note)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(plan.tint.opacity(0.94))
                    }

                    Spacer(minLength: 8)

                    Text(plan.etaLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                .padding(.vertical, 2)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

private struct TrafficSurfacePanel: View {
    let scene: LiveTrafficScene
    let status: TileDeliveryState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 10) {
                        Text("Pressure Build vs Release")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        TileStatusBadge(state: status)
                    }
                    Text("Recent fee-lane pressure so you can tell whether congestion is genuinely clearing or simply refilling after each block.")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.68))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(scene.depthWindowLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.58))
                    Text(scene.momentumLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(scene.queueDriftTint.opacity(0.92))
                }
            }

            HStack(spacing: 10) {
                SurfaceInsightPill(title: "Hot corridor", value: scene.primaryRouteCode, tint: .orange)
                SurfaceInsightPill(title: "Urgent lane", value: scene.urgentBandShareLabel, tint: .red)
                SurfaceInsightPill(title: "Last block", value: scene.blockEventDetail, tint: .mint)
            }

            SurfaceChart(scene: scene)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

private struct SurfaceInsightPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.48))
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.24), lineWidth: 1)
                )
        )
    }
}

private struct SurfaceChart: View {
    let scene: LiveTrafficScene

    var body: some View {
        GeometryReader { _ in
            Canvas(rendersAsynchronously: true) { context, size in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 14, dy: 12)

                let gridLines = 4
                for gridIndex in 0...gridLines {
                    let y = rect.maxY - (CGFloat(gridIndex) / CGFloat(gridLines)) * (rect.height - 28)
                    var path = Path()
                    path.move(to: CGPoint(x: rect.minX, y: y))
                    path.addLine(to: CGPoint(x: rect.maxX, y: y))
                    context.stroke(path, with: .color(Color.white.opacity(0.08)), lineWidth: 1)
                }

                let bandColors: [Color] = [.mint, .yellow, .orange, .red]

                for bandIndex in scene.bandIndicesInBackToFrontOrder {
                    let points = scene.surfacePoints(
                        for: bandIndex,
                        in: rect
                    )

                    guard points.count > 1 else {
                        continue
                    }

                    var fillPath = Path()
                    fillPath.move(to: CGPoint(x: points[0].x, y: rect.maxY - CGFloat(bandIndex) * 18))

                    for point in points {
                        fillPath.addLine(to: point)
                    }

                    if let last = points.last {
                        fillPath.addLine(to: CGPoint(x: last.x, y: rect.maxY - CGFloat(bandIndex) * 18))
                    }
                    fillPath.closeSubpath()

                    let color = bandColors[min(bandIndex, bandColors.count - 1)]
                    context.fill(fillPath, with: .linearGradient(
                        Gradient(colors: [color.opacity(0.34), color.opacity(0.06)]),
                        startPoint: CGPoint(x: rect.midX, y: rect.minY),
                        endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                    ))

                    var linePath = Path()
                    linePath.addLines(points)
                    context.stroke(
                        linePath,
                        with: .color(color.opacity(0.95)),
                        style: StrokeStyle(lineWidth: bandIndex == scene.highlightBandIndex ? 3 : 2, lineCap: .round, lineJoin: .round)
                    )
                }

                let marker = scene.activeMarkerX(in: rect)
                var markerPath = Path()
                markerPath.move(to: CGPoint(x: marker, y: rect.minY))
                markerPath.addLine(to: CGPoint(x: marker, y: rect.maxY))
                context.stroke(
                    markerPath,
                    with: .color(Color.white.opacity(0.18)),
                    style: StrokeStyle(lineWidth: 1.4, dash: [6, 6])
                )
            }
        }
    }
}

private struct LiveTrafficScene {
    let timeline: ReplayTimeline
    let activeIndex: Int
    let activeFrame: ReplayFrame
    let previousFrame: ReplayFrame?
    let recentFrames: [ReplayFrame]
    let baseRotation: Double

    init(timeline: ReplayTimeline, activeIndex: Int, phase: Double) {
        self.timeline = timeline

        if timeline.frames.isEmpty {
            let fallback = ReplayFrame(
                timestamp: timeline.generatedAt,
                stateLabel: "No replay frames",
                mempoolStressScore: 0,
                queuedVBytes: 0,
                estimatedBlocksToClear: 0,
                feeBands: []
            )
            self.activeIndex = 0
            self.activeFrame = fallback
            self.previousFrame = nil
            self.recentFrames = [fallback]
            self.baseRotation = 0
            return
        }

        let frameIndex = min(max(activeIndex, 0), timeline.frames.count - 1)
        self.activeIndex = frameIndex
        self.activeFrame = timeline.frames[frameIndex]
        self.previousFrame = frameIndex > 0 ? timeline.frames[frameIndex - 1] : nil

        let lowerBound = max(frameIndex - 23, 0)
        self.recentFrames = Array(timeline.frames[lowerBound...frameIndex])
        self.baseRotation = phase / 8
    }

    var queuedLabel: String {
        byteCountLabel(activeFrame.queuedVBytes)
    }

    var relayThroughput: Int {
        max(Int(activeFrame.mempoolStressScore * 9) + estimatedVisibleHubCount * 11, 0)
    }

    var dominantBand: FeeBand {
        activeFrame.feeBands.max(by: { $0.queuedVBytes < $1.queuedVBytes })
            ?? FeeBand(label: "N/A", minFee: 0, maxFee: 0, queuedVBytes: 0, estimatedBlocksToClear: 0)
    }

    var queueDriftLabel: String {
        guard let previousFrame else {
            return "stable"
        }

        let delta = activeFrame.queuedVBytes - previousFrame.queuedVBytes
        if abs(delta) < 50_000 {
            return "flat"
        }

        let signed = delta > 0 ? "+" : ""
        return "\(signed)\(byteCountLabel(abs(delta)))"
    }

    var queueDriftTint: Color {
        guard let previousFrame else {
            return .white
        }

        let delta = activeFrame.queuedVBytes - previousFrame.queuedVBytes
        if abs(delta) < 50_000 {
            return .white
        }
        return delta > 0 ? .orange : .mint
    }

    var blockEventLabel: String {
        if let clearance = activeFrame.blockClearance {
            return "#\(clearance.blockHeight)"
        }
        return "pending"
    }

    var blockEventDetail: String {
        if let clearance = activeFrame.blockClearance {
            return "Cleared \(byteCountLabel(clearance.clearedVBytes))"
        }
        return "Awaiting clearance"
    }

    var recommendedBandIndex: Int {
        if activeFrame.mempoolStressScore >= 84 || activeFrame.estimatedBlocksToClear >= 7 {
            return 0
        }
        if activeFrame.mempoolStressScore >= 66 || queueDelta > 180_000 {
            return min(1, max(activeFrame.feeBands.count - 1, 0))
        }
        if activeFrame.mempoolStressScore >= 48 {
            return min(2, max(activeFrame.feeBands.count - 1, 0))
        }
        return min(3, max(activeFrame.feeBands.count - 1, 0))
    }

    var recommendedBand: FeeBand {
        guard activeFrame.feeBands.indices.contains(recommendedBandIndex) else {
            return FeeBand(label: "Observe", minFee: 0, maxFee: 0, queuedVBytes: 0, estimatedBlocksToClear: 0)
        }
        return activeFrame.feeBands[recommendedBandIndex]
    }

    var recommendedBandFeeLabel: String {
        feeRangeLabel(for: recommendedBand)
    }

    var actionRecommendation: ActionRecommendation {
        let band = recommendedBand

        if recommendedBandIndex == 0 {
            return ActionRecommendation(
                title: "Delay non-urgent sends",
                summary: "The queue is still stacked and the urgent lane is already crowded. Waiting for a clearance event should improve cost more than chasing the current spike.",
                nextStep: "If settlement cannot wait, bid into \(feeRangeLabel(for: band)) for roughly \(blocksLabel(band.estimatedBlocksToClear)).",
                badge: "WAIT",
                tint: .orange
            )
        }

        if recommendedBandIndex == 1 {
            return ActionRecommendation(
                title: "Pay for certainty if timing matters",
                summary: "Pressure is elevated but not broken. The fast lanes are carrying the most load, so standard sends may drift upward before the next block lands.",
                nextStep: "Use \(feeRangeLabel(for: band)) if you need confirmation within about \(blocksLabel(band.estimatedBlocksToClear)).",
                badge: "PAY UP",
                tint: .yellow
            )
        }

        if recommendedBandIndex == 2 {
            return ActionRecommendation(
                title: "Standard settlement window is open",
                summary: "Traffic is still active, but the queue is manageable enough that you do not need to overpay unless the transfer is genuinely urgent.",
                nextStep: "Base execution around \(feeRangeLabel(for: band)) and monitor whether queue drift stays flat or turns lower.",
                badge: "SEND",
                tint: .mint
            )
        }

        return ActionRecommendation(
            title: "Low-fee window is open",
            summary: "Congestion is subdued and lower-priority traffic is clearing cleanly. This is the best moment for flexible settlement.",
            nextStep: "The low-priority lane around \(feeRangeLabel(for: band)) should clear in roughly \(blocksLabel(band.estimatedBlocksToClear)).",
            badge: "CHEAP",
            tint: .cyan
        )
    }

    var nextReliefShortLabel: String {
        if activeFrame.blockClearance != nil {
            return "Now"
        }
        return "~\(estimatedMinutesToNextClearance)m"
    }

    var nextReliefDetail: String {
        if activeFrame.blockClearance != nil {
            return "Fresh block opened a temporary window"
        }

        if queueDelta < -120_000 {
            return "Cooling into the next block cycle"
        }

        return "Based on recent block cadence and queue refill"
    }

    var momentumLabel: String {
        if queueDelta > 180_000 {
            return "Pressure is still building"
        }
        if queueDelta < -180_000 {
            return "Queue is cooling"
        }
        return "Pressure is mostly flat"
    }

    var momentumDetail: String {
        if queueDelta > 180_000 {
            return "Refill is outrunning recent clearances"
        }
        if queueDelta < -180_000 {
            return "Recent clearances are buying some room"
        }
        return "No major shift versus the previous frame"
    }

    var primaryRouteLabel: String {
        routeSummaries.first?.label ?? "No dominant corridor"
    }

    var primaryRouteCode: String {
        routeSummaries.first?.shortLabel ?? "Stable"
    }

    var urgentBandShareLabel: String {
        guard activeFrame.queuedVBytes > 0,
              let urgentBand = activeFrame.feeBands.first else {
            return "0%"
        }

        let share = Double(urgentBand.queuedVBytes) / Double(activeFrame.queuedVBytes)
        return "\(Int((share * 100).rounded()))%"
    }

    var watchpoints: [HubWatchpoint] {
        globeProjection(rotationOffset: 0)
            .nodes
            .sorted {
                if $0.liveStatus.queueBytes == $1.liveStatus.queueBytes {
                    return $0.liveStatus.utilization > $1.liveStatus.utilization
                }
                return $0.liveStatus.queueBytes > $1.liveStatus.queueBytes
            }
            .prefix(4)
            .map { hub in
                HubWatchpoint(
                    id: hub.id,
                    label: hub.hub.name,
                    subtitle: "\(hub.hub.region) • \(hub.liveStatus.lane.label)",
                    impact: hub.settlementImpactSummary,
                    tone: hub.liveStatus.executionTone,
                    loadLabel: hub.liveStatus.queueLabel,
                    tint: hub.color
                )
            }
    }

    var executionPlans: [ExecutionPlan] {
        activeFrame.feeBands.enumerated().map { index, band in
            let tint = Self.routeColor(for: index)

            return ExecutionPlan(
                id: "\(index)-\(band.label)",
                label: band.label,
                detail: "\(feeRangeLabel(for: band)) • \(byteCountLabel(band.queuedVBytes)) waiting",
                note: executionNote(for: band, index: index),
                etaLabel: blocksLabel(band.estimatedBlocksToClear),
                isRecommended: index == recommendedBandIndex,
                tint: tint
            )
        }
    }

    var routeSummaries: [RouteSummary] {
        Self.routeCatalog
            .sorted(by: { Self.weightedBandLoad(for: $0, frame: activeFrame) > Self.weightedBandLoad(for: $1, frame: activeFrame) })
            .prefix(4)
            .map { route in
                let band = activeFrame.feeBands.indices.contains(route.bandIndex)
                    ? activeFrame.feeBands[route.bandIndex]
                    : FeeBand(label: "Base", minFee: 0, maxFee: 0, queuedVBytes: 0, estimatedBlocksToClear: 0)
                let from = Self.hubCatalog[route.from]
                let to = Self.hubCatalog[route.to]

                return RouteSummary(
                    label: "\(from.name) to \(to.name)",
                    shortLabel: "\(from.name.prefix(3)).\(to.name.prefix(3))",
                    subtitle: "\(band.label) lane carrying \(byteCountLabel(band.queuedVBytes))",
                    intensity: "\(band.label.uppercased())",
                    tint: Self.routeColor(for: route.bandIndex)
                )
            }
    }

    var bandIndicesInBackToFrontOrder: [Int] {
        Array(activeFrame.feeBands.indices.reversed())
    }

    var highlightBandIndex: Int {
        activeFrame.feeBands.enumerated().max(by: { $0.element.queuedVBytes < $1.element.queuedVBytes })?.offset ?? 0
    }

    var depthWindowLabel: String {
        if let first = recentFrames.first?.timestamp, let last = recentFrames.last?.timestamp {
            let formatter = Date.FormatStyle().hour().minute()
            return "\(first.formatted(formatter)) to \(last.formatted(formatter))"
        }
        return "Recent frames"
    }

    func surfacePoints(for bandIndex: Int, in rect: CGRect) -> [CGPoint] {
        guard !recentFrames.isEmpty else {
            return []
        }

        let maxQueued = max(
            recentFrames
                .compactMap { $0.feeBands.indices.contains(bandIndex) ? $0.feeBands[bandIndex].queuedVBytes : 0 }
                .max() ?? 1,
            1
        )

        let usableHeight = rect.height - 34
        let bandDepth = CGFloat(bandIndex) * 18
        let xInset = 18 + CGFloat(bandIndex) * 12
        let usableWidth = rect.width - xInset - 18

        return recentFrames.enumerated().map { index, frame in
            let band = frame.feeBands.indices.contains(bandIndex)
                ? frame.feeBands[bandIndex]
                : FeeBand(label: "", minFee: 0, maxFee: 0, queuedVBytes: 0, estimatedBlocksToClear: 0)
            let progress = recentFrames.count == 1 ? 1.0 : Double(index) / Double(recentFrames.count - 1)
            let normalized = CGFloat(band.queuedVBytes) / CGFloat(maxQueued)

            return CGPoint(
                x: rect.minX + xInset + CGFloat(progress) * usableWidth,
                y: rect.maxY - bandDepth - max(normalized * usableHeight * 0.74, 6)
            )
        }
    }

    func activeMarkerX(in rect: CGRect) -> CGFloat {
        let markerCount = max(recentFrames.count - 1, 1)
        let progress = CGFloat(markerCount) / CGFloat(markerCount)
        return rect.minX + 18 + progress * (rect.width - 36)
    }

    func globeProjection(rotationOffset: Double) -> GlobeProjection {
        let rotation = baseRotation + rotationOffset
        let nodes = Self.hubCatalog.enumerated().map { index, hub in
            Self.project(hub: hub, index: index, frame: activeFrame, rotation: rotation, relayThroughput: relayThroughput)
        }
        let routes = Self.routeCatalog.filter { route in
            route.from < nodes.count && route.to < nodes.count
        }.map { route in
            Self.project(route: route, nodes: nodes, frame: activeFrame)
        }

        return GlobeProjection(rotation: rotation, nodes: nodes, routes: routes)
    }

    private var estimatedVisibleHubCount: Int {
        Self.hubCatalog.filter { hub in
            globeCoordinate(latitude: hub.latitude, longitude: hub.longitude, rotation: baseRotation).depth > -0.15
        }.count
    }

    private static let hubCatalog = SettlementPressureGlobeModel.hubs

    private static let routeCatalog = SettlementPressureGlobeModel.routes

    private static func project(
        hub: HubDefinition,
        index: Int,
        frame: ReplayFrame,
        rotation: Double,
        relayThroughput: Int
    ) -> ProjectedHub {
        let coordinate = globeCoordinate(latitude: hub.latitude, longitude: hub.longitude, rotation: rotation)
        let pulse = (sin(rotation * 2 + Double(index)) + 1) / 2
        let intensity = min(max(frame.mempoolStressScore / 100 * hub.bias + pulse * 0.16, 0.18), 1.0)
        let lane = SettlementPressureGlobeModel.dominantBand(for: index, frame: frame)
        let utilization = min(max(0.28 + intensity * 0.62, 0.18), 0.98)
        let relayShare = min(max((hub.bias * 0.52) + (intensity * 0.34), 0.18), 0.96)
        let throughput = max(Int(Double(relayThroughput) * (0.42 + hub.bias * 0.58) * (0.55 + intensity * 0.45)), 40)
        let queueBytes = max(Int(Double(frame.queuedVBytes) * (0.010 + hub.bias * 0.022) * (0.48 + intensity * 0.52)), 10_000)
        let status: String
        if utilization > 0.84 {
            status = "Primary relay"
        } else if utilization > 0.66 {
            status = "Regional balancer"
        } else {
            status = "Standby edge"
        }

        return ProjectedHub(
            hub: hub,
            point: coordinate.point,
            depth: coordinate.depth,
            radius: 5 + CGFloat(intensity * 10),
            color: hub.color.opacity(0.78 + intensity * 0.22),
            liveStatus: HubLiveStatus(
                utilization: utilization,
                relayShare: relayShare,
                throughput: throughput,
                queueBytes: queueBytes,
                lane: lane,
                status: status,
                latencyMs: hub.averageLatencyMs + Int(utilization * 7),
                uptime: min(99.99, 98.9 + hub.bias * 0.82 - utilization * 0.16)
            )
        )
    }

    private static func project(route: Route, nodes: [ProjectedHub], frame: ReplayFrame) -> ProjectedRoute {
        let from = nodes[route.from]
        let to = nodes[route.to]
        let band = frame.feeBands.indices.contains(route.bandIndex)
            ? frame.feeBands[route.bandIndex]
            : FeeBand(label: "Base", minFee: 0, maxFee: 0, queuedVBytes: 0, estimatedBlocksToClear: 0)

        let screenFrom = from.point
        let screenTo = to.point
        let mid = CGPoint(x: (screenFrom.x + screenTo.x) / 2, y: (screenFrom.y + screenTo.y) / 2)
        let lift = CGFloat(0.20 + route.emphasis * 0.08)
        let control = CGPoint(x: mid.x * 0.72, y: mid.y * 0.72 - lift)

        let intensity = min(max(Double(band.queuedVBytes) / 1_600_000 * route.emphasis, 0.18), 1.0)

        return ProjectedRoute(
            from: from,
            to: to,
            control: control,
            color: SettlementPressureGlobeModel.routeColor(for: route.bandIndex),
            opacity: 0.28 + intensity * 0.46,
            lineWidth: 1.2 + intensity * 2.2,
            emphasis: route.emphasis,
            band: band
        )
    }

    private static func weightedBandLoad(for route: Route, frame: ReplayFrame) -> Double {
        SettlementPressureGlobeModel.weightedBandLoad(for: route, frame: frame)
    }

    private static func routeColor(for bandIndex: Int) -> Color {
        SettlementPressureGlobeModel.routeColor(for: bandIndex)
    }

    private func byteCountLabel(_ value: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(value))
    }

    private var queueDelta: Int {
        activeFrame.queuedVBytes - (previousFrame?.queuedVBytes ?? activeFrame.queuedVBytes)
    }

    private var estimatedMinutesToNextClearance: Int {
        guard let lastClearanceTimestamp else {
            return max(Int((activeFrame.estimatedBlocksToClear * 10 / 2).rounded()), 8)
        }

        let elapsedMinutes = activeFrame.timestamp.timeIntervalSince(lastClearanceTimestamp) / 60
        let remainingMinutes = max(averageClearanceIntervalMinutes - elapsedMinutes, 2)
        return Int(remainingMinutes.rounded())
    }

    private var lastClearanceTimestamp: Date? {
        recentFrames.last(where: { $0.blockClearance != nil })?.timestamp
    }

    private var averageClearanceIntervalMinutes: Double {
        let timestamps = recentFrames.compactMap { frame in
            frame.blockClearance != nil ? frame.timestamp : nil
        }

        guard timestamps.count >= 2 else {
            return 10
        }

        let intervals = zip(timestamps, timestamps.dropFirst()).map { previous, next in
            next.timeIntervalSince(previous) / 60
        }

        guard !intervals.isEmpty else {
            return 10
        }

        return intervals.reduce(0, +) / Double(intervals.count)
    }

    private func feeRangeLabel(for band: FeeBand) -> String {
        let minFee = Int(band.minFee.rounded())
        let maxFee = Int(band.maxFee.rounded())
        if minFee == maxFee {
            return "\(minFee) sat/vB"
        }
        return "\(minFee)-\(maxFee) sat/vB"
    }

    private func blocksLabel(_ blocks: Double) -> String {
        if abs(blocks - 1) < 0.15 {
            return "1 block"
        }
        return String(format: "%.1f blocks", blocks)
    }

    private func executionNote(for band: FeeBand, index: Int) -> String {
        if index == recommendedBandIndex {
            return "Best tradeoff for the current queue shape."
        }
        if index < recommendedBandIndex {
            return "Higher price buys more certainty if the next block matters."
        }
        return "Cheaper, but more exposed if refill continues."
    }
}

private typealias HubDefinition = SettlementPressureGlobeModel.Hub
private typealias Route = SettlementPressureGlobeModel.Route

private struct GlobeProjection {
    let rotation: Double
    let nodes: [ProjectedHub]
    let routes: [ProjectedRoute]

    var visibleNodeCount: Int {
        nodes.filter { $0.depth > -0.15 }.count
    }
}

private struct HubLiveStatus {
    let utilization: Double
    let relayShare: Double
    let throughput: Int
    let queueBytes: Int
    let lane: FeeBand
    let status: String
    let latencyMs: Int
    let uptime: Double

    var latencyLabel: String {
        "\(latencyMs) ms"
    }

    var queueLabel: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(queueBytes))
    }

    var uptimeLabel: String {
        String(format: "%.2f%%", uptime)
    }

    var executionTone: String {
        if utilization > 0.84 {
            return "Escalating"
        }
        if utilization > 0.66 {
            return "Tight"
        }
        return "Flexible"
    }
}

private struct ProjectedHub: Identifiable {
    var id: String { hub.id }
    let hub: HubDefinition
    let point: CGPoint
    let depth: Double
    let radius: CGFloat
    let color: Color
    let liveStatus: HubLiveStatus

    var settlementImpactSummary: String {
        if liveStatus.utilization > 0.84 {
            return "Urgent senders are already competing here, so lower-fee transactions are likely to lose position if pressure keeps refilling."
        }
        if liveStatus.utilization > 0.66 {
            return "This hub is still absorbent, but it can push standard transactions into a higher fee lane if the queue keeps building."
        }
        return "This hub looks relatively absorbent and is less likely to force a near-term fee escalation on its own."
    }
}

private struct ProjectedRoute {
    let from: ProjectedHub
    let to: ProjectedHub
    let control: CGPoint
    let color: Color
    let opacity: Double
    let lineWidth: Double
    let emphasis: Double
    let band: FeeBand
}

private struct GlobeLayout {
    let rect: CGRect
    let center: CGPoint
    let radius: CGFloat

    init(size: CGSize) {
        rect = CGRect(origin: .zero, size: size).insetBy(dx: 18, dy: 18)
        let diameter = min(
            max(min(rect.width * 0.72, rect.height * 0.84), 260),
            520
        )
        radius = diameter / 2
        center = CGPoint(
            x: rect.minX + radius + 24,
            y: rect.minY + radius + 20
        )
    }

    var sphereRect: CGRect {
        CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
    }

    func screenPoint(for normalizedPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: center.x + normalizedPoint.x * radius,
            y: center.y - normalizedPoint.y * radius
        )
    }

    func liftedPoint(for normalizedPoint: CGPoint, multiplier: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + normalizedPoint.x * radius * multiplier,
            y: center.y - normalizedPoint.y * radius * multiplier
        )
    }

    func calloutPoint(for hub: ProjectedHub) -> CGPoint {
        let point = screenPoint(for: hub.point)
        let horizontalOffset: CGFloat = hub.point.x >= 0 ? 88 : -88
        let verticalOffset = -26 - CGFloat(max(hub.depth, 0)) * 12

        return CGPoint(
            x: clamp(point.x + horizontalOffset, min: rect.minX + 92, max: rect.maxX - 92),
            y: clamp(point.y + verticalOffset, min: rect.minY + 28, max: rect.maxY - 28)
        )
    }
}

private struct RouteSummary: Identifiable {
    let id = UUID()
    let label: String
    let shortLabel: String
    let subtitle: String
    let intensity: String
    let tint: Color
}

private struct ActionRecommendation {
    let title: String
    let summary: String
    let nextStep: String
    let badge: String
    let tint: Color
}

private struct HubWatchpoint: Identifiable {
    let id: String
    let label: String
    let subtitle: String
    let impact: String
    let tone: String
    let loadLabel: String
    let tint: Color
}

private struct ExecutionPlan: Identifiable {
    let id: String
    let label: String
    let detail: String
    let note: String
    let etaLabel: String
    let isRecommended: Bool
    let tint: Color
}

private typealias GlobeCoordinate = SettlementPressureGlobeModel.Coordinate
private typealias GlobeVector = SettlementPressureGlobeModel.Vector

private struct LandLatitudeRow {
    let latitude: Double
    let longitudes: [Double]
}

private func graticulePath(
    center: CGPoint,
    radius: CGFloat,
    rotation: Double,
    fixedLatitude: Double? = nil,
    fixedLongitude: Double? = nil
) -> Path {
    var path = Path()
    let steps = 64
    var shouldMove = true

    for step in 0...steps {
        let progress = Double(step) / Double(steps)
        let latitude = fixedLatitude ?? (-80 + progress * 160)
        let longitude = fixedLongitude ?? (-180 + progress * 360)

        let coordinate = globeCoordinate(latitude: latitude, longitude: longitude, rotation: rotation)
        guard coordinate.depth > 0.02 else {
            shouldMove = true
            continue
        }

        let point = CGPoint(
            x: center.x + coordinate.point.x * radius,
            y: center.y - coordinate.point.y * radius
        )

        if shouldMove {
            path.move(to: point)
            shouldMove = false
        } else {
            path.addLine(to: point)
        }
    }

    return path
}

private func globeCoordinate(latitude: Double, longitude: Double, rotation: Double) -> GlobeCoordinate {
    SettlementPressureGlobeModel.coordinate(latitude: latitude, longitude: longitude, rotation: rotation)
}

private func surfaceRoutePath(
    from: HubDefinition,
    to: HubDefinition,
    rotation: Double,
    layout: GlobeLayout
) -> Path {
    var path = Path()
    var shouldMove = true

    for coordinate in greatCircleCoordinates(from: from, to: to, rotation: rotation) {
        guard coordinate.depth > 0.02 else {
            shouldMove = true
            continue
        }

        let point = layout.screenPoint(for: coordinate.point)
        if shouldMove {
            path.move(to: point)
            shouldMove = false
        } else {
            path.addLine(to: point)
        }
    }

    return path
}

private func greatCircleCoordinates(
    from: HubDefinition,
    to: HubDefinition,
    rotation: Double,
    steps: Int = 48
) -> [GlobeCoordinate] {
    SettlementPressureGlobeModel.greatCircleCoordinates(from: from, to: to, rotation: rotation, steps: steps)
}

private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
    Swift.min(Swift.max(value, minimum), maximum)
}

private func globeVector(latitude: Double, longitude: Double) -> GlobeVector {
    SettlementPressureGlobeModel.vector(latitude: latitude, longitude: longitude)
}

private func projectVector(_ vector: GlobeVector, rotation: Double) -> GlobeCoordinate {
    SettlementPressureGlobeModel.project(vector, rotation: rotation)
}

private func normalize(_ vector: GlobeVector) -> GlobeVector {
    SettlementPressureGlobeModel.normalize(vector)
}

private func dot(_ lhs: GlobeVector, _ rhs: GlobeVector) -> Double {
    SettlementPressureGlobeModel.dot(lhs, rhs)
}

// Derived from Natural Earth public-domain 1:110m land polygons.
private let sourcedLandRows: [LandLatitudeRow] = [
    LandLatitudeRow(latitude: -82.0, longitudes: [-58.0, -54.0]),
    LandLatitudeRow(latitude: -78.0, longitudes: [-70.0, -66.0, -62.0, -58.0, -54.0, -50.0, -46.0, -42.0, -38.0]),
    LandLatitudeRow(latitude: -74.0, longitudes: [-58.0, -54.0, -50.0, -46.0, -42.0, -38.0, -34.0, -30.0, -26.0, -22.0, -18.0]),
    LandLatitudeRow(latitude: -70.0, longitudes: [-70.0, -62.0, -58.0, -54.0, -50.0, -46.0, -42.0, -38.0, -34.0, -30.0, -26.0, -22.0, -18.0, -14.0, -10.0, -6.0, -2.0, 2.0, 6.0, 10.0, 22.0, 26.0, 70.0]),
    LandLatitudeRow(latitude: -66.0, longitudes: [-62.0, -58.0, -54.0, -50.0, -46.0, -42.0, -38.0, -34.0, -30.0, -26.0, -22.0, -18.0, -14.0, -10.0, -6.0, -2.0, 2.0, 6.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 42.0, 46.0, 50.0, 58.0, 62.0, 66.0, 70.0, 74.0, 78.0, 82.0, 86.0, 90.0, 94.0, 98.0, 102.0, 106.0, 110.0, 118.0]),
    LandLatitudeRow(latitude: -54.0, longitudes: [-70.0]),
    LandLatitudeRow(latitude: -50.0, longitudes: [-74.0, -70.0]),
    LandLatitudeRow(latitude: -46.0, longitudes: [-74.0, -70.0, 170.0]),
    LandLatitudeRow(latitude: -42.0, longitudes: [-74.0, -70.0, -66.0, 146.0, 174.0]),
    LandLatitudeRow(latitude: -38.0, longitudes: [-70.0, -66.0, -62.0, -58.0, 142.0, 146.0, 178.0]),
    LandLatitudeRow(latitude: -34.0, longitudes: [-70.0, -66.0, -62.0, -58.0, -54.0, 22.0, 118.0, 138.0, 142.0, 146.0, 150.0]),
    LandLatitudeRow(latitude: -30.0, longitudes: [-70.0, -66.0, -62.0, -58.0, -54.0, 18.0, 22.0, 26.0, 30.0, 118.0, 122.0, 126.0, 130.0, 134.0, 138.0, 142.0, 146.0, 150.0]),
    LandLatitudeRow(latitude: -26.0, longitudes: [-70.0, -66.0, -62.0, -58.0, -54.0, -50.0, 18.0, 22.0, 26.0, 30.0, 114.0, 118.0, 122.0, 126.0, 130.0, 134.0, 138.0, 142.0, 146.0, 150.0]),
    LandLatitudeRow(latitude: -22.0, longitudes: [-70.0, -66.0, -62.0, -58.0, -54.0, -50.0, -46.0, -42.0, 18.0, 22.0, 26.0, 30.0, 34.0, 46.0, 118.0, 122.0, 126.0, 130.0, 134.0, 138.0, 142.0, 146.0, 166.0]),
    LandLatitudeRow(latitude: -18.0, longitudes: [-70.0, -66.0, -62.0, -58.0, -54.0, -50.0, -46.0, -42.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 46.0, 126.0, 130.0, 134.0, 138.0, 142.0, 146.0, 178.0]),
    LandLatitudeRow(latitude: -14.0, longitudes: [-74.0, -70.0, -66.0, -62.0, -58.0, -54.0, -50.0, -46.0, -42.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 50.0, 130.0, 134.0, 142.0]),
    LandLatitudeRow(latitude: -10.0, longitudes: [-78.0, -74.0, -70.0, -66.0, -62.0, -58.0, -54.0, -50.0, -46.0, -42.0, -38.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 150.0]),
    LandLatitudeRow(latitude: -6.0, longitudes: [-78.0, -74.0, -70.0, -66.0, -62.0, -58.0, -54.0, -50.0, -46.0, -42.0, -38.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 106.0, 142.0, 146.0, 150.0]),
    LandLatitudeRow(latitude: -2.0, longitudes: [-78.0, -74.0, -70.0, -66.0, -62.0, -58.0, -54.0, -50.0, -46.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 102.0, 114.0, 134.0, 138.0]),
    LandLatitudeRow(latitude: 2.0, longitudes: [-78.0, -74.0, -70.0, -66.0, -62.0, -58.0, -54.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 42.0, 114.0]),
    LandLatitudeRow(latitude: 6.0, longitudes: [-74.0, -70.0, -66.0, -62.0, -58.0, -10.0, -6.0, -2.0, 6.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 42.0, 46.0, 102.0]),
    LandLatitudeRow(latitude: 10.0, longitudes: [-74.0, -70.0, -66.0, -14.0, -10.0, -6.0, -2.0, 2.0, 6.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 42.0, 46.0, 50.0, 78.0, 106.0]),
    LandLatitudeRow(latitude: 14.0, longitudes: [-90.0, -86.0, -14.0, -10.0, -6.0, -2.0, 2.0, 6.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 46.0, 78.0, 102.0, 106.0, 122.0]),
    LandLatitudeRow(latitude: 18.0, longitudes: [-102.0, -98.0, -94.0, -90.0, -66.0, -14.0, -10.0, -6.0, -2.0, 2.0, 6.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 42.0, 46.0, 50.0, 54.0, 74.0, 78.0, 82.0, 98.0, 102.0, 106.0, 122.0]),
    LandLatitudeRow(latitude: 22.0, longitudes: [-102.0, -98.0, -78.0, -14.0, -10.0, -6.0, -2.0, 2.0, 6.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 42.0, 46.0, 50.0, 54.0, 58.0, 70.0, 74.0, 78.0, 82.0, 86.0, 90.0, 94.0, 98.0, 102.0, 106.0, 110.0]),
    LandLatitudeRow(latitude: 26.0, longitudes: [-106.0, -102.0, -98.0, -14.0, -10.0, -6.0, -2.0, 2.0, 6.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 42.0, 46.0, 50.0, 58.0, 62.0, 66.0, 70.0, 74.0, 78.0, 82.0, 86.0, 90.0, 94.0, 98.0, 102.0, 106.0, 110.0, 114.0, 118.0]),
    LandLatitudeRow(latitude: 30.0, longitudes: [-110.0, -106.0, -102.0, -98.0, -94.0, -90.0, -82.0, -6.0, -2.0, 2.0, 6.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 42.0, 46.0, 54.0, 58.0, 62.0, 66.0, 70.0, 74.0, 78.0, 82.0, 86.0, 90.0, 94.0, 98.0, 102.0, 106.0, 110.0, 114.0, 118.0]),
    LandLatitudeRow(latitude: 34.0, longitudes: [-118.0, -114.0, -110.0, -106.0, -102.0, -98.0, -94.0, -90.0, -86.0, -82.0, -78.0, -6.0, -2.0, 2.0, 6.0, 10.0, 38.0, 42.0, 46.0, 50.0, 54.0, 58.0, 62.0, 66.0, 70.0, 74.0, 78.0, 82.0, 86.0, 90.0, 94.0, 98.0, 102.0, 106.0, 110.0, 114.0, 118.0, 134.0]),
    LandLatitudeRow(latitude: 38.0, longitudes: [-122.0, -118.0, -114.0, -110.0, -106.0, -102.0, -98.0, -94.0, -90.0, -86.0, -82.0, -78.0, -6.0, -2.0, 14.0, 22.0, 30.0, 34.0, 38.0, 42.0, 46.0, 54.0, 58.0, 62.0, 66.0, 70.0, 74.0, 78.0, 82.0, 86.0, 90.0, 94.0, 98.0, 102.0, 106.0, 110.0, 114.0, 118.0, 126.0]),
    LandLatitudeRow(latitude: 42.0, longitudes: [-122.0, -118.0, -114.0, -110.0, -106.0, -102.0, -98.0, -94.0, -90.0, -86.0, -82.0, -78.0, -74.0, -70.0, -6.0, -2.0, 2.0, 14.0, 22.0, 26.0, 34.0, 42.0, 46.0, 54.0, 58.0, 62.0, 66.0, 70.0, 74.0, 78.0, 82.0, 86.0, 90.0, 94.0, 98.0, 102.0, 106.0, 110.0, 114.0, 118.0, 122.0, 126.0, 130.0]),
    LandLatitudeRow(latitude: 46.0, longitudes: [-122.0, -118.0, -114.0, -110.0, -106.0, -102.0, -98.0, -94.0, -90.0, -86.0, -82.0, -78.0, -74.0, -70.0, -66.0, 2.0, 6.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 42.0, 46.0, 54.0, 58.0, 62.0, 66.0, 70.0, 74.0, 78.0, 82.0, 86.0, 90.0, 94.0, 98.0, 102.0, 106.0, 110.0, 114.0, 118.0, 122.0, 126.0, 130.0, 134.0]),
    LandLatitudeRow(latitude: 50.0, longitudes: [-126.0, -122.0, -118.0, -114.0, -110.0, -106.0, -102.0, -98.0, -94.0, -90.0, -86.0, -82.0, -78.0, -74.0, -70.0, 2.0, 6.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 42.0, 46.0, 50.0, 54.0, 58.0, 62.0, 66.0, 70.0, 74.0, 78.0, 82.0, 86.0, 90.0, 94.0, 98.0, 102.0, 106.0, 110.0, 114.0, 118.0, 122.0, 126.0, 130.0, 134.0, 138.0]),
    LandLatitudeRow(latitude: 54.0, longitudes: [-130.0, -126.0, -122.0, -118.0, -114.0, -110.0, -106.0, -102.0, -98.0, -94.0, -90.0, -86.0, -78.0, -74.0, -70.0, -66.0, -62.0, -58.0, -2.0, 10.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 42.0, 46.0, 50.0, 54.0, 58.0, 62.0, 66.0, 70.0, 74.0, 78.0, 82.0, 86.0, 90.0, 94.0, 98.0, 102.0, 106.0, 110.0, 114.0, 118.0, 122.0, 126.0, 130.0, 134.0, 158.0]),
    LandLatitudeRow(latitude: 58.0, longitudes: [-134.0, -130.0, -126.0, -122.0, -118.0, -114.0, -110.0, -106.0, -102.0, -98.0, -94.0, -74.0, -70.0, -66.0, 14.0, 26.0, 30.0, 34.0, 38.0, 42.0, 46.0, 50.0, 54.0, 58.0, 62.0, 66.0, 70.0, 74.0, 78.0, 82.0, 86.0, 90.0, 94.0, 98.0, 102.0, 106.0, 110.0, 114.0, 118.0, 122.0, 126.0, 130.0, 134.0, 138.0, 158.0, 162.0]),
    LandLatitudeRow(latitude: 62.0, longitudes: [-162.0, -158.0, -154.0, -150.0, -146.0, -142.0, -138.0, -134.0, -130.0, -126.0, -122.0, -118.0, -114.0, -110.0, -106.0, -102.0, -98.0, -94.0, -78.0, -74.0, -46.0, 6.0, 10.0, 14.0, 22.0, 26.0, 30.0, 34.0, 38.0, 42.0, 46.0, 50.0, 54.0, 58.0, 62.0, 66.0, 70.0, 74.0, 78.0, 82.0, 86.0, 90.0, 94.0, 98.0, 102.0, 106.0, 110.0, 114.0, 118.0, 122.0, 126.0, 130.0, 134.0, 138.0, 142.0, 146.0, 150.0, 154.0, 158.0, 162.0, 166.0, 170.0, 174.0]),
    LandLatitudeRow(latitude: 66.0, longitudes: [-178.0, -174.0, -170.0, -166.0, -162.0, -158.0, -154.0, -150.0, -146.0, -142.0, -138.0, -134.0, -130.0, -126.0, -122.0, -118.0, -114.0, -110.0, -106.0, -102.0, -98.0, -94.0, -90.0, -74.0, -70.0, -66.0, -50.0, -46.0, -42.0, -38.0, -22.0, -18.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 42.0, 46.0, 50.0, 54.0, 58.0, 62.0, 66.0, 70.0, 74.0, 78.0, 82.0, 86.0, 90.0, 94.0, 98.0, 102.0, 106.0, 110.0, 114.0, 118.0, 122.0, 126.0, 130.0, 134.0, 138.0, 142.0, 146.0, 150.0, 154.0, 158.0, 162.0, 166.0, 170.0, 174.0, 178.0]),
    LandLatitudeRow(latitude: 70.0, longitudes: [-162.0, -158.0, -154.0, -150.0, -146.0, -130.0, -114.0, -110.0, -106.0, -102.0, -98.0, -94.0, -82.0, -78.0, -74.0, -70.0, -54.0, -50.0, -46.0, -42.0, -38.0, -34.0, -30.0, -26.0, 22.0, 26.0, 30.0, 70.0, 74.0, 78.0, 82.0, 86.0, 90.0, 94.0, 98.0, 102.0, 106.0, 110.0, 114.0, 118.0, 122.0, 126.0, 130.0, 134.0, 138.0, 142.0, 146.0, 150.0, 154.0, 158.0]),
    LandLatitudeRow(latitude: 74.0, longitudes: [-122.0, -118.0, -94.0, -54.0, -50.0, -46.0, -42.0, -38.0, -34.0, -30.0, -26.0, -22.0, 58.0, 90.0, 94.0, 98.0, 102.0, 106.0, 110.0]),
    LandLatitudeRow(latitude: 78.0, longitudes: [-110.0, -82.0, -78.0, -70.0, -66.0, -62.0, -58.0, -54.0, -50.0, -46.0, -42.0, -38.0, -34.0, -30.0, -26.0, -22.0, 14.0, 18.0, 22.0]),
    LandLatitudeRow(latitude: 82.0, longitudes: [-90.0, -86.0, -82.0, -78.0, -74.0, -70.0, -66.0, -58.0, -54.0, -50.0, -46.0, -42.0, -38.0, -34.0, -30.0])
]
