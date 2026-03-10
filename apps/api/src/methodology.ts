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
        usage: "Live mempool congestion, fee bands, and short-term stress"
      },
      {
        id: "fred-series",
        class: "B",
        usage: "Delayed macro context for liquidity and risk framing"
      },
      {
        id: "etf-flow-proxy",
        class: "B",
        usage: "Publicly attributable ETF flow context with explicit partial coverage"
      }
    ],
    freshnessRules: [
      "Mempool data is treated as live when fetched successfully during request assembly.",
      "Macro inputs degrade from live to delayed when the latest observation is older than two calendar days.",
      "Known flow inputs degrade to stale when daily flow data is older than 36 hours.",
      "Demo data is allowed for internal prototypes, but always carries an explicit confidence penalty."
    ],
    limitations: [
      "Known flows are intentionally incomplete in the MVP and should not be interpreted as omniscient capital tracking.",
      "Replay history is currently generated from deterministic fixtures until snapshot persistence is added.",
      "Macro scoring describes backdrop and does not attempt to predict Bitcoin price direction."
    ]
  };
}
