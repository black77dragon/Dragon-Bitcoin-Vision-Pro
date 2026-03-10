import type {
  ConfidenceBreakdown,
  EvidenceCard,
  RegimeState,
  ScoreCard,
  ScoreDirection,
  SourceStamp
} from "./contracts.ts";
import type { FlowSignal, MacroSignal, MempoolSignal } from "./fixtures.ts";

export interface ScoreBundle {
  mempool: ScoreCard;
  macro: ScoreCard;
  flows: ScoreCard;
  confidence: ConfidenceBreakdown;
  regime: RegimeState;
  evidence: EvidenceCard[];
  narrative: string;
}

export function buildScoreBundle(input: {
  mempoolSignal: MempoolSignal;
  macroSignal: MacroSignal;
  flowSignal: FlowSignal;
}): ScoreBundle {
  const mempool = buildMempoolScore(input.mempoolSignal);
  const macro = buildMacroScore(input.macroSignal);
  const flows = buildFlowScore(input.flowSignal);
  const confidence = buildConfidence(
    [
      ...input.mempoolSignal.sources,
      ...input.macroSignal.sources,
      ...input.flowSignal.sources
    ],
    [input.mempoolSignal.live ? 1 : 0.82, input.macroSignal.coverage, input.flowSignal.coverage],
    [mempool.value, macro.value, flows.value]
  );
  const regime = buildRegimeState({
    mempoolScore: mempool.value,
    macroScore: macro.value,
    flowScore: flows.value,
    persistenceRatio: input.mempoolSignal.persistenceRatio
  });
  const evidence = buildEvidenceCards({
    mempoolSignal: input.mempoolSignal,
    macroSignal: input.macroSignal,
    flowSignal: input.flowSignal,
    mempoolScore: mempool,
    macroScore: macro,
    flowScore: flows
  });
  const narrative = buildNarrative(regime, evidence, confidence);

  return {
    mempool,
    macro,
    flows,
    confidence,
    regime,
    evidence,
    narrative
  };
}

export function buildMempoolScore(signal: MempoolSignal): ScoreCard {
  const feeFloorPercentile = clamp(signal.minFee / 40 * 100, 0, 100);
  const queuePercentile = clamp(signal.queuedVBytes / 8_000_000 * 100, 0, 100);
  const blocksToClear = clamp(signal.estimatedBlocksToClear / 10 * 100, 0, 100);
  const refillPersistence = clamp((signal.persistenceRatio * 0.65 + signal.refillRatio * 0.35) * 100, 0, 100);
  const value = weighted([
    [feeFloorPercentile, 0.35],
    [queuePercentile, 0.25],
    [blocksToClear, 0.2],
    [refillPersistence, 0.2]
  ]);

  return {
    key: "mempoolStress",
    label: "Mempool Stress",
    value,
    direction: scoreDirection(value, { elevated: 68, restrictive: 52 }),
    summary: `Fee floor ${signal.minFee} sat/vB with ${signal.estimatedBlocksToClear.toFixed(1)} blocks to clear.`,
    contributionWeight: 0.42,
    sourceIds: signal.sources.map((source) => source.id)
  };
}

export function buildMacroScore(signal: MacroSignal): ScoreCard {
  const dollarComponent = clamp(55 - (signal.dollarIndex.latest - signal.dollarIndex.previous) * 12, 0, 100);
  const realYieldComponent = clamp(72 - signal.realYield10y.latest * 18, 0, 100);
  const liquidityComponent = clamp(
    45 + ((signal.liquidityProxy.latest - signal.liquidityProxy.previous) / signal.liquidityProxy.previous) * 2_200,
    0,
    100
  );
  const riskComponent = clamp(
    50 + ((signal.riskProxy.latest - signal.riskProxy.previous) / signal.riskProxy.previous) * 2_500,
    0,
    100
  );
  const value = weighted([
    [dollarComponent, 0.3],
    [realYieldComponent, 0.3],
    [liquidityComponent, 0.2],
    [riskComponent, 0.2]
  ]);

  return {
    key: "macroLiquidity",
    label: "Macro Liquidity",
    value,
    direction: value >= 58 ? "supportive" : value >= 42 ? "neutral" : "restrictive",
    summary: `Dollar and real yields are ${value >= 58 ? "less restrictive" : value < 42 ? "restrictive" : "mixed"} for Bitcoin risk appetite.`,
    contributionWeight: 0.28,
    sourceIds: signal.sources.map((source) => source.id)
  };
}

export function buildFlowScore(signal: FlowSignal): ScoreCard {
  const netFlowComponent = clamp(50 + signal.netEtfFlowUsd / 12_000_000, 0, 100);
  const changeComponent = clamp(
    50 + (signal.netEtfFlowUsd - signal.previousNetEtfFlowUsd) / 10_000_000,
    0,
    100
  );
  const coverageComponent = clamp(signal.coverage * 100, 0, 100);
  const value = weighted([
    [netFlowComponent, 0.55],
    [changeComponent, 0.25],
    [coverageComponent, 0.2]
  ]);

  return {
    key: "knownFlowPressure",
    label: "Known Flow Pressure",
    value,
    direction: value >= 58 ? "supportive" : value >= 42 ? "neutral" : "restrictive",
    summary: `${formatUsd(signal.netEtfFlowUsd)} of observable ETF flow with ${(signal.coverage * 100).toFixed(0)}% coverage.`,
    contributionWeight: 0.3,
    sourceIds: signal.sources.map((source) => source.id)
  };
}

export function buildConfidence(
  sources: SourceStamp[],
  coverageInputs: number[],
  values: number[]
): ConfidenceBreakdown {
  const timeliness = round(
    average(
      sources.map((source) => {
        if (source.status === "demo") {
          return 0.7 - source.confidencePenalty;
        }
        if (source.status === "stale") {
          return 0.35;
        }
        if (source.status === "delayed") {
          return 0.65 - source.confidencePenalty;
        }
        return 0.95 - source.confidencePenalty;
      })
    ),
    2
  );
  const coverage = round(average(coverageInputs), 2);
  const dispersion = Math.max(...values) - Math.min(...values);
  const agreement = round(clamp(1 - dispersion / 120, 0.35, 0.95), 2);
  const overall = round(clamp(timeliness * 0.45 + coverage * 0.35 + agreement * 0.2, 0.2, 0.95), 2);
  const notes = buildConfidenceNotes({ timeliness, coverage, agreement, sources });

  return { overall, timeliness, coverage, agreement, notes };
}

export function buildRegimeState(input: {
  mempoolScore: number;
  macroScore: number;
  flowScore: number;
  persistenceRatio: number;
}): RegimeState {
  const { mempoolScore, macroScore, flowScore, persistenceRatio } = input;

  if (mempoolScore < 45 && macroScore >= 55 && flowScore >= 52) {
    return {
      key: "calmAccumulation",
      label: "Calm Accumulation",
      summary: "Blockspace is clearing and macro conditions are not actively restrictive.",
      alertLevel: "normal"
    };
  }

  if (macroScore < 38 && flowScore < 45) {
    return {
      key: "distributionRisk",
      label: "Distribution Risk",
      summary: "Macro liquidity and observable flow context are leaning against sustained demand.",
      alertLevel: "elevated"
    };
  }

  if (mempoolScore >= 80 && persistenceRatio < 0.58) {
    return {
      key: "speculativeSpike",
      label: "Speculative Spike",
      summary: "Stress is high, but refill behavior suggests a less durable burst.",
      alertLevel: "watch"
    };
  }

  if (mempoolScore >= 78 && persistenceRatio >= 0.58 && flowScore >= 52) {
    return {
      key: "structurallyCongested",
      label: "Structurally Congested",
      summary: "Elevated fee floors are persisting after block clearances, which implies durable demand.",
      alertLevel: "elevated"
    };
  }

  if (mempoolScore >= 62) {
    return {
      key: "elevatedNetworkStress",
      label: "Elevated Network Stress",
      summary: "Bitcoin blockspace is crowded and worth deeper inspection in the arena.",
      alertLevel: "watch"
    };
  }

  return {
    key: "mixedEvidence",
    label: "Mixed Evidence",
    summary: "Inputs do not align into a single clean regime yet.",
    alertLevel: "watch"
  };
}

function buildEvidenceCards(input: {
  mempoolSignal: MempoolSignal;
  macroSignal: MacroSignal;
  flowSignal: FlowSignal;
  mempoolScore: ScoreCard;
  macroScore: ScoreCard;
  flowScore: ScoreCard;
}): EvidenceCard[] {
  return [
    {
      id: "mempool-floor",
      title: "Fee floor persistence",
      valueLabel: `${input.mempoolSignal.minFee} sat/vB floor`,
      interpretation:
        input.mempoolSignal.persistenceRatio >= 0.58
          ? "Elevated fees are sticking after block clearances."
          : "Recent stress still looks event-driven rather than durable.",
      direction: input.mempoolScore.direction,
      weight: 0.42,
      freshnessLabel: freshnessLabel(input.mempoolSignal.sources),
      sourceIds: input.mempoolSignal.sources.map((source) => source.id)
    },
    {
      id: "macro-backdrop",
      title: "Macro backdrop",
      valueLabel: `${input.macroScore.value.toFixed(0)}/100`,
      interpretation:
        input.macroScore.direction === "supportive"
          ? "Macro conditions are not strongly fighting Bitcoin demand."
          : input.macroScore.direction === "restrictive"
            ? "Dollar and real-yield pressure are reducing risk support."
            : "Macro inputs are mixed and should remain supporting context only.",
      direction: input.macroScore.direction,
      weight: 0.28,
      freshnessLabel: freshnessLabel(input.macroSignal.sources),
      sourceIds: input.macroSignal.sources.map((source) => source.id)
    },
    {
      id: "flow-context",
      title: "Known flow context",
      valueLabel: formatUsd(input.flowSignal.netEtfFlowUsd),
      interpretation:
        input.flowScore.direction === "supportive"
          ? "Observable ETF demand is supportive, though coverage is partial."
          : input.flowScore.direction === "restrictive"
            ? "Observable flows are not offsetting current market pressure."
            : "Known flows are broadly neutral or incomplete.",
      direction: input.flowScore.direction,
      weight: 0.3,
      freshnessLabel: freshnessLabel(input.flowSignal.sources),
      sourceIds: input.flowSignal.sources.map((source) => source.id)
    }
  ];
}

function buildNarrative(
  regime: RegimeState,
  evidence: EvidenceCard[],
  confidence: ConfidenceBreakdown
): string {
  const strongest = evidence
    .slice()
    .sort((left, right) => right.weight - left.weight)
    .slice(0, 2)
    .map((card) => card.title.toLowerCase())
    .join(" and ");

  return `Regime: ${regime.label}. Evidence: ${strongest}. Confidence: ${confidence.overall.toFixed(2)}.`;
}

function scoreDirection(
  value: number,
  thresholds: { elevated: number; restrictive: number }
): ScoreDirection {
  if (value >= thresholds.elevated) {
    return "elevated";
  }
  if (value >= thresholds.restrictive) {
    return "neutral";
  }
  return "supportive";
}

function buildConfidenceNotes(input: {
  timeliness: number;
  coverage: number;
  agreement: number;
  sources: SourceStamp[];
}): string[] {
  const notes: string[] = [];

  if (input.timeliness < 0.7) {
    notes.push("At least one supporting source is demo-backed, delayed, or stale.");
  }

  if (input.coverage < 0.75) {
    notes.push("Known flow and macro coverage remain partial in the MVP pipeline.");
  }

  if (input.agreement < 0.7) {
    notes.push("Scores are diverging, so the headline state should be treated as provisional.");
  }

  if (notes.length === 0) {
    notes.push("Source freshness and score agreement are currently strong.");
  }

  return notes;
}

function freshnessLabel(sources: SourceStamp[]): string {
  const liveSource = sources.find((source) => source.status === "live");
  if (liveSource) {
    return "Live";
  }

  const delayedSource = sources.find((source) => source.status === "delayed");
  if (delayedSource) {
    return "Delayed";
  }

  return "Demo";
}

function average(values: number[]): number {
  return values.reduce((total, value) => total + value, 0) / values.length;
}

function weighted(entries: Array<[number, number]>): number {
  const total = entries.reduce((sum, [value, weight]) => sum + value * weight, 0);
  return round(clamp(total, 0, 100), 1);
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function round(value: number, decimals: number): number {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}

function formatUsd(value: number): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    notation: "compact",
    maximumFractionDigits: 1
  }).format(value);
}
