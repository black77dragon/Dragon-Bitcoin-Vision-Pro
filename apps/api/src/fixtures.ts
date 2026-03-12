import type {
  FeeBand,
  ReplayBucket,
  ReplayFrame,
  ReplayRange,
  SourceStamp
} from "./contracts.ts";

export interface MetricSignal {
  id: string;
  label: string;
  latest: number;
  previous: number;
  unit: string;
  source: SourceStamp;
}

export interface MempoolSignal {
  minFee: number;
  fastestFee: number;
  queuedVBytes: number;
  estimatedBlocksToClear: number;
  persistenceRatio: number;
  refillRatio: number;
  feeBands: FeeBand[];
  sources: SourceStamp[];
  live: boolean;
}

export interface MacroSignal {
  dollarIndex: MetricSignal;
  realYield10y: MetricSignal;
  liquidityProxy: MetricSignal;
  riskProxy: MetricSignal;
  coverage: number;
  sources: SourceStamp[];
  live: boolean;
  headlineSummary?: string;
}

export interface FlowSignal {
  netEtfFlowUsd: number;
  previousNetEtfFlowUsd: number;
  coverage: number;
  sources: SourceStamp[];
  live: boolean;
}

export interface BitcoinPriceSignal {
  priceUsd: number;
  deltaUsd?: number;
  sources: SourceStamp[];
  live: boolean;
}

export function buildDemoMempoolSignal(now = new Date()): MempoolSignal {
  const source = buildSourceStamp({
    id: "mempool-demo",
    name: "Mempool Demo Dataset",
    licenseClass: "A",
    cadence: "near-real-time",
    status: "demo",
    fetchedAt: now,
    freshnessSeconds: 0,
    confidencePenalty: 0.18,
    note: "Deterministic fixture used for offline product reviews."
  });

  return {
    minFee: 20,
    fastestFee: 42,
    queuedVBytes: 6_850_000,
    estimatedBlocksToClear: 7.8,
    persistenceRatio: 0.72,
    refillRatio: 0.66,
    feeBands: buildFeeBands(6_850_000, 20, 42),
    sources: [source],
    live: false
  };
}

export function buildDemoMacroSignal(now = new Date()): MacroSignal {
  const sources = [
    buildSourceStamp({
      id: "fred-dxy-demo",
      name: "FRED Broad Dollar Demo",
      licenseClass: "B",
      cadence: "daily",
      status: "demo",
      fetchedAt: now,
      freshnessSeconds: 0,
      confidencePenalty: 0.12
    }),
    buildSourceStamp({
      id: "fred-real-yield-demo",
      name: "FRED Real Yield Demo",
      licenseClass: "B",
      cadence: "daily",
      status: "demo",
      fetchedAt: now,
      freshnessSeconds: 0,
      confidencePenalty: 0.12
    }),
    buildSourceStamp({
      id: "fred-liquidity-demo",
      name: "FRED Liquidity Demo",
      licenseClass: "B",
      cadence: "weekly",
      status: "demo",
      fetchedAt: now,
      freshnessSeconds: 0,
      confidencePenalty: 0.16
    }),
    buildSourceStamp({
      id: "fred-risk-demo",
      name: "FRED Risk Proxy Demo",
      licenseClass: "B",
      cadence: "daily",
      status: "demo",
      fetchedAt: now,
      freshnessSeconds: 0,
      confidencePenalty: 0.12
    })
  ];

  return {
    dollarIndex: {
      id: "dollarIndex",
      label: "Dollar Strength",
      latest: 123.4,
      previous: 124.7,
      unit: "index",
      source: sources[0]
    },
    realYield10y: {
      id: "realYield10y",
      label: "10Y Real Yield",
      latest: 1.68,
      previous: 1.75,
      unit: "%",
      source: sources[1]
    },
    liquidityProxy: {
      id: "liquidityProxy",
      label: "Liquidity Proxy",
      latest: 7_216,
      previous: 7_180,
      unit: "bn",
      source: sources[2]
    },
    riskProxy: {
      id: "riskProxy",
      label: "Risk-On Proxy",
      latest: 5_210,
      previous: 5_168,
      unit: "index",
      source: sources[3]
    },
    coverage: 0.75,
    sources,
    live: false
  };
}

export function buildDemoFlowSignal(now = new Date()): FlowSignal {
  const source = buildSourceStamp({
    id: "etf-flows-demo",
    name: "ETF Flow Demo Dataset",
    licenseClass: "B",
    cadence: "daily",
    status: "demo",
    fetchedAt: now,
    freshnessSeconds: 0,
    confidencePenalty: 0.18,
    note: "Represents public ETF flow context with partial market coverage."
  });

  return {
    netEtfFlowUsd: 185_000_000,
    previousNetEtfFlowUsd: 142_000_000,
    coverage: 0.55,
    sources: [source],
    live: false
  };
}

export function buildDemoBitcoinPriceSignal(now = new Date()): BitcoinPriceSignal {
  const source = buildSourceStamp({
    id: "btc-price-demo",
    name: "BTC/USD Demo Feed",
    licenseClass: "A",
    cadence: "near-real-time",
    status: "demo",
    fetchedAt: now,
    freshnessSeconds: 0,
    confidencePenalty: 0.14,
    note: "Synthetic BTC/USD price used when the live quote feed is unavailable."
  });

  const phase = now.getTime() / 600_000;
  const priceUsd = round(82_400 + Math.sin(phase) * 580 + Math.cos(phase * 1.7) * 160, 2);
  const deltaUsd = round(Math.sin(phase * 1.9) * 92, 2);

  return {
    priceUsd,
    deltaUsd,
    sources: [source],
    live: false
  };
}

export function buildDemoReplayFrames(
  range: ReplayRange,
  bucket: ReplayBucket,
  now = new Date(),
  anchorScore = 71
): ReplayFrame[] {
  const totalMinutes = range === "24h" ? 24 * 60 : 6 * 60;
  const stepMinutes = bucket === "5m" ? 5 : 1;
  const frameCount = Math.floor(totalMinutes / stepMinutes);
  const start = new Date(now.getTime() - totalMinutes * 60_000);
  const frames: ReplayFrame[] = [];
  let blockHeight = 886_000;

  for (let index = 0; index < frameCount; index += 1) {
    const minuteOffset = index * stepMinutes;
    const timestamp = new Date(start.getTime() + minuteOffset * 60_000);
    const wave = Math.sin(index / 5) * 8 + Math.cos(index / 11) * 6;
    const trend = range === "24h" ? Math.sin(index / 17) * 4 : Math.cos(index / 9) * 5;
    let score = clamp(anchorScore + wave + trend, 22, 94);
    const hasClearance = minuteOffset > 0 && minuteOffset % 10 === 0;
    const queueBase = 2_600_000 + score * 46_000;
    const queuedVBytes = Math.max(
      900_000,
      Math.round(queueBase - (hasClearance ? 720_000 : 0) + Math.sin(index / 3) * 110_000)
    );
    const estimatedBlocksToClear = round(queuedVBytes / 1_000_000 + score / 32, 1);

    if (hasClearance) {
      score = clamp(score - 7, 20, 94);
      blockHeight += 1;
    }

    const minFee = clamp(Math.round(score / 4), 4, 44);
    const maxFee = clamp(Math.round(score / 2.2), 12, 95);
    const feeBands = buildFeeBands(queuedVBytes, minFee, maxFee);

    frames.push({
      timestamp: timestamp.toISOString(),
      stateLabel: stateLabelForScore(score),
      mempoolStressScore: round(score, 1),
      queuedVBytes,
      estimatedBlocksToClear,
      feeBands,
      blockClearance: hasClearance
        ? {
            blockHeight,
            clearedVBytes: 960_000,
            feeFloorAfter: Math.max(minFee - 4, 2)
          }
        : undefined
    });
  }

  return frames;
}

export function buildReplaySource(now = new Date()): SourceStamp {
  return buildSourceStamp({
    id: "replay-demo",
    name: "Replay Snapshot Generator",
    licenseClass: "A",
    cadence: "1m rolling snapshots",
    status: "demo",
    fetchedAt: now,
    freshnessSeconds: 0,
    confidencePenalty: 0.1,
    note: "Replace with persisted snapshots once backend storage is added."
  });
}

export function buildSourceStamp(input: {
  id: string;
  name: string;
  licenseClass: SourceStamp["licenseClass"];
  cadence: string;
  status: SourceStamp["status"];
  fetchedAt: Date;
  freshnessSeconds: number;
  confidencePenalty: number;
  note?: string;
  publishedAt?: Date;
}): SourceStamp {
  return {
    id: input.id,
    name: input.name,
    licenseClass: input.licenseClass,
    cadence: input.cadence,
    status: input.status,
    fetchedAt: input.fetchedAt.toISOString(),
    publishedAt: input.publishedAt?.toISOString(),
    freshnessSeconds: input.freshnessSeconds,
    confidencePenalty: input.confidencePenalty,
    note: input.note
  };
}

export function buildFeeBands(totalQueuedVBytes: number, minFee: number, maxFee: number): FeeBand[] {
  const bandWeights = [0.4, 0.28, 0.19, 0.13];
  const labels = ["Urgent", "Soon", "Base fee zone", "Low priority"];
  const lowerBounds = [Math.max(maxFee - 8, minFee + 10), minFee + 8, minFee + 2, 1];
  const upperBounds = [maxFee, maxFee - 9, minFee + 7, minFee + 1];

  return bandWeights.map((weight, index) => ({
    label: labels[index],
    minFee: Math.max(1, lowerBounds[index]),
    maxFee: Math.max(lowerBounds[index], upperBounds[index]),
    queuedVBytes: Math.round(totalQueuedVBytes * weight),
    estimatedBlocksToClear: round((totalQueuedVBytes * weight) / 1_000_000 + index * 0.6, 1)
  }));
}

function stateLabelForScore(score: number): string {
  if (score >= 80) {
    return "Very busy, not clearing";
  }
  if (score >= 68) {
    return "Busy and staying busy";
  }
  if (score >= 52) {
    return "Manageable traffic";
  }
  return "Quiet";
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function round(value: number, decimals: number): number {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}
