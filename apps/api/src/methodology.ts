import type { MethodologyResponse } from "./contracts.ts";

export function buildMethodologyResponse(now = new Date()): MethodologyResponse {
  return {
    updatedAt: now.toISOString(),
    scoreWeights: {
      mempoolStress: {
        persistentFeeFloorPercentile: 0.35,
        queuedVBytesPercentile: 0.25,
        estimatedBlocksToClear: 0.2,
        postBlockRefillPersistence: 0.2
      },
      macroLiquidity: {
        dollarStrengthProxy: 0.3,
        realYield10yProxy: 0.3,
        liquidityProxy: 0.2,
        riskOnOffProxy: 0.2
      },
      knownFlowPressure: {
        netEtfFlowBias: 0.55,
        flowAcceleration: 0.25,
        coveragePenalty: 0.2
      }
    },
    sourceCatalog: [
      {
        id: "mempool-space",
        class: "A",
        usage: "Live Bitcoin network traffic, fee levels, and short-term queue pressure"
      },
      {
        id: "macro-signal-feed",
        class: "B",
        usage: "Broader market backdrop, using production data with a FRED-based fallback"
      },
      {
        id: "glassnode-etf-flows",
        class: "B",
        usage: "Primary U.S. spot ETF net-flow series used as the main visible large-buyer proxy"
      },
      {
        id: "etf-flow-proxy",
        class: "B",
        usage: "Optional internal override for ETF aggregates when a custom feed is available"
      }
    ],
    freshnessRules: [
      "Network traffic data is treated as live when it is fetched successfully during the current request.",
      "Broader market inputs are marked delayed when they are older than the normal daily or weekly update schedule.",
      "Tracked flow inputs are marked stale when the daily flow data is more than 36 hours old.",
      "Demo data is allowed for prototypes, but it always lowers confidence."
    ],
    limitations: [
      "Large-buyer tracking is intentionally incomplete in the MVP, so it is only a partial view of market demand.",
      "Glassnode ETF totals can be annotated with a Farside cross-check, but that validation is still based on public daily aggregates rather than true real-time creation data.",
      "Replay uses saved snapshots when available and temporarily backfills missing history until enough live frames accumulate.",
      "The broader market score describes conditions around Bitcoin. It is not a direct price forecast."
    ]
  };
}
