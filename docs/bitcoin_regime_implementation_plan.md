# Bitcoin Regime Navigator MVP Implementation Plan

## Product goal

Deliver an internal Apple Vision Pro-first MVP that can answer two questions in under 60 seconds:

1. What is the current Bitcoin regime?
2. Why does the product believe that?

## Phase 0 deliverables in this repository

- Original concept documents under `docs/concept/`
- Repo-level implementation plan and API contract
- Dependency-light TypeScript backend for `GET /v1/briefing/current`, `GET /v1/mempool/replay`, and `GET /v1/methodology`
- Swift package with shared domain models, demo data, Daily Briefing UI, methodology UI, and Mempool Arena visualization primitives
- Tests for scoring, API assembly, replay behavior, and Swift domain behaviors

## MVP architecture

### Backend

- Runtime: Node 24 with native fetch and test runner
- Style: serverless-friendly HTTP handler with no framework dependency
- Data sources:
  - live mempool data via `mempool.space`
  - optional FRED-backed macro data when `FRED_API_KEY` is present
  - Glassnode U.S. spot ETF flows as the primary large-buyer feed when `GLASSNODE_API_KEY` is present
  - optional Farside daily cross-check note for ETF totals
  - optional ETF flow proxy override when `ETF_FLOW_PROXY_URL` is present
  - deterministic demo fallback for offline development and investor demos

### Client foundation

- Runtime: Swift 6 package intended to be consumed by a future visionOS app target
- UI stack: SwiftUI first, with a path for RealityKit-backed arena attachments later
- Core modules:
  - `BitcoinRegimeDomain` for contracts, service interfaces, demo data, and local snapshots
  - `BitcoinRegimeUI` for Daily Briefing, methodology, strips, and Mempool Arena views

## Locked interfaces

- `GET /v1/briefing/current`
  - returns `RegimeSnapshot`
  - accepts `mode=auto|demo|live`
- `GET /v1/mempool/replay`
  - returns `ReplayTimeline`
  - accepts `range=6h|24h`, `bucket=1m|5m`, `mode=auto|demo|live`
- `GET /v1/methodology`
  - returns score weights, freshness rules, source catalog, and limitations

## Scoring defaults

### Mempool Stress Score

- 35% persistent fee-floor percentile
- 25% queued vbytes percentile
- 20% estimated blocks to clear
- 20% post-block refill persistence

### Macro Liquidity Score

- 30% dollar-strength proxy
- 30% 10Y real-yield proxy
- 20% liquidity proxy
- 20% risk-on/off proxy

### Known Flow Pressure Score

- ETF net-flow bias with explicit coverage penalties
- partial coverage lowers confidence before it changes the headline narrative

## Phase 1 follow-through after this scaffold

- wire the Swift package into a real visionOS app target
- replace demo macro and ETF adapters with production feeds
- persist replay snapshots in managed Postgres
- add local snapshots and alert history into the app shell
- harden on real Vision Pro hardware for seated use

## Acceptance criteria

- a user can identify the current regime within 10 seconds
- the evidence row explains the regime within 60 seconds
- replay exposes live state plus at least 6 hours of reviewable history
- each score exposes source, freshness, and confidence metadata
