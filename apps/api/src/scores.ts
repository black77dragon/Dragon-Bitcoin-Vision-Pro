import type {
  ConfidenceBreakdown,
  EvidenceCard,
  MarketWeatherComponent,
  MarketWeatherDetail,
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
  marketWeather: MarketWeatherDetail;
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
  const marketWeather = buildMarketWeatherDetail(input.macroSignal, macro);
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
    marketWeather,
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
    label: "Network Traffic",
    value,
    direction: scoreDirection(value, { elevated: 68, restrictive: 52 }),
    summary:
      value >= 68
        ? `The Bitcoin network is crowded. Typical low-end fees are around ${signal.minFee} sat/vB, and the queue would take about ${signal.estimatedBlocksToClear.toFixed(1)} blocks to clear.`
        : value >= 52
          ? `Network traffic is building. Typical low-end fees are around ${signal.minFee} sat/vB, and the queue is about ${signal.estimatedBlocksToClear.toFixed(1)} blocks deep.`
          : `Network traffic is fairly light. Typical low-end fees are around ${signal.minFee} sat/vB, and the queue is about ${signal.estimatedBlocksToClear.toFixed(1)} blocks deep.`,
    contributionWeight: 0.42,
    sourceIds: signal.sources.map((source) => source.id)
  };
}

export function buildMacroScore(signal: MacroSignal): ScoreCard {
  const { dollarComponent, realYieldComponent, liquidityComponent, riskComponent } =
    buildMacroComponentValues(signal);
  const value = weighted([
    [dollarComponent, 0.3],
    [realYieldComponent, 0.3],
    [liquidityComponent, 0.2],
    [riskComponent, 0.2]
  ]);

  return {
    key: "macroLiquidity",
    label: "Broader Market Weather",
    value,
    direction: value >= 58 ? "supportive" : value >= 42 ? "neutral" : "restrictive",
    summary:
      value >= 58
        ? "The wider market backdrop is helping more than hurting. Money conditions are not strongly pushing investors away from risk."
        : value < 42
          ? "The wider market backdrop is working against risk-taking. That usually makes it harder for Bitcoin to attract fresh demand."
          : "The wider market backdrop is mixed. It is not giving Bitcoin a strong push in either direction.",
    contributionWeight: 0.28,
    sourceIds: signal.sources.map((source) => source.id)
  };
}

export function buildMarketWeatherDetail(
  signal: MacroSignal,
  score: Pick<ScoreCard, "value" | "summary">
): MarketWeatherDetail {
  const { dollarComponent, realYieldComponent, liquidityComponent, riskComponent } =
    buildMacroComponentValues(signal);

  return {
    score: round(score.value, 1),
    outlook: marketWeatherOutlook(score.value),
    summary: score.summary,
    components: [
      buildMarketWeatherComponent(signal.dollarIndex, dollarComponent, 0.3),
      buildMarketWeatherComponent(signal.realYield10y, realYieldComponent, 0.3),
      buildMarketWeatherComponent(signal.liquidityProxy, liquidityComponent, 0.2),
      buildMarketWeatherComponent(signal.riskProxy, riskComponent, 0.2)
    ]
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
    label: "Big Buyer Activity",
    value,
    direction: value >= 58 ? "supportive" : value >= 42 ? "neutral" : "restrictive",
    summary:
      value >= 58
        ? `Tracked large buyers, including visible ETF flows, added about ${formatUsd(signal.netEtfFlowUsd)}. We can currently see ${(signal.coverage * 100).toFixed(0)}% of the picture.`
        : value < 42
          ? `Tracked large buyers are not adding enough support right now. Visible flow is about ${formatUsd(signal.netEtfFlowUsd)} with ${(signal.coverage * 100).toFixed(0)}% coverage.`
          : `Tracked large-buyer flow is roughly balanced. Visible flow is about ${formatUsd(signal.netEtfFlowUsd)} with ${(signal.coverage * 100).toFixed(0)}% coverage.`,
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
      label: "Quiet, Healthy Demand",
      summary: "The network is clearing smoothly and the broader backdrop is not getting in Bitcoin's way.",
      alertLevel: "normal"
    };
  }

  if (macroScore < 38 && flowScore < 45) {
    return {
      key: "distributionRisk",
      label: "Demand Losing Strength",
      summary: "The market backdrop and visible large-buyer flows both suggest demand is fading rather than strengthening.",
      alertLevel: "elevated"
    };
  }

  if (mempoolScore >= 80 && persistenceRatio < 0.58) {
    return {
      key: "speculativeSpike",
      label: "Short-Lived Rush",
      summary: "Activity is hot right now, but it still looks more like a burst of excitement than a lasting wave of demand.",
      alertLevel: "watch"
    };
  }

  if (mempoolScore >= 78 && persistenceRatio >= 0.58 && flowScore >= 52) {
    return {
      key: "structurallyCongested",
      label: "Strong Demand, Crowded Network",
      summary: "The network stays busy even after blocks clear, which usually points to demand that keeps coming back.",
      alertLevel: "elevated"
    };
  }

  if (mempoolScore >= 62) {
    return {
      key: "elevatedNetworkStress",
      label: "Busy Network, Worth Watching",
      summary: "Bitcoin traffic is elevated enough that sending coins is harder and the queue deserves a closer look.",
      alertLevel: "watch"
    };
  }

  return {
    key: "mixedEvidence",
    label: "Mixed Signals",
    summary: "The inputs do not yet tell one clean story, so this read should be treated as tentative.",
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
  const macroInterpretation =
    input.macroScore.direction === "supportive"
      ? "Outside conditions are reasonably friendly for risk-taking, so macro is not putting heavy pressure on Bitcoin."
      : input.macroScore.direction === "restrictive"
        ? "Higher cash yields and a firmer dollar are making investors more cautious, which can weigh on Bitcoin demand."
        : "The outside backdrop is mixed, so it should be treated as context rather than a decisive signal.";

  return [
    {
      id: "mempool-floor",
      title: "Base transaction cost",
      valueLabel: `${input.mempoolSignal.minFee} sat/vB floor`,
      interpretation:
        input.mempoolSignal.persistenceRatio >= 0.58
          ? "Even after new blocks are mined, the cheapest workable fee stays high. That is a sign the queue is refilling quickly."
          : "Fees spiked, but they are not staying high for long. That points to a temporary surge rather than steady pressure.",
      direction: input.mempoolScore.direction,
      weight: 0.42,
      freshnessLabel: freshnessLabel(input.mempoolSignal.sources),
      sourceIds: input.mempoolSignal.sources.map((source) => source.id)
    },
    {
      id: "macro-backdrop",
      title: "Broader market backdrop",
      valueLabel: `${input.macroScore.value.toFixed(0)}/100`,
      interpretation: [macroInterpretation, input.macroSignal.headlineSummary].filter(Boolean).join(" "),
      direction: input.macroScore.direction,
      weight: 0.28,
      freshnessLabel: freshnessLabel(input.macroSignal.sources),
      sourceIds: input.macroSignal.sources.map((source) => source.id)
    },
    {
      id: "flow-context",
      title: "Large tracked buying",
      valueLabel: formatUsd(input.flowSignal.netEtfFlowUsd),
      interpretation:
        input.flowScore.direction === "supportive"
          ? "Visible large buyers are adding support. This mainly reflects public ETF data, and it is still only part of the full market."
          : input.flowScore.direction === "restrictive"
            ? "Visible large buyers are not strong enough to counter the current pressure in the market."
            : "Tracked buying is either balanced or incomplete, so it is not a strong signal on its own.",
      direction: input.flowScore.direction,
      weight: 0.3,
      freshnessLabel: freshnessLabel(input.flowSignal.sources),
      sourceIds: input.flowSignal.sources.map((source) => source.id)
    }
  ];
}

function buildMacroComponentValues(signal: MacroSignal) {
  return {
    dollarComponent: clamp(55 - (signal.dollarIndex.latest - signal.dollarIndex.previous) * 12, 0, 100),
    realYieldComponent: clamp(72 - signal.realYield10y.latest * 18, 0, 100),
    liquidityComponent: clamp(
      45 + ((signal.liquidityProxy.latest - signal.liquidityProxy.previous) / signal.liquidityProxy.previous) * 2_200,
      0,
      100
    ),
    riskComponent: clamp(
      50 + ((signal.riskProxy.latest - signal.riskProxy.previous) / signal.riskProxy.previous) * 2_500,
      0,
      100
    )
  };
}

function buildMarketWeatherComponent(
  metric: MacroSignal["dollarIndex"],
  score: number,
  weight: number
): MarketWeatherComponent {
  const effect = directionalWeatherEffect(score);
  const change = metric.latest - metric.previous;
  const changePrefix = change > 0 ? "Up" : change < 0 ? "Down" : "Flat";

  return {
    id: metric.id,
    title: metric.label,
    score: round(score, 1),
    valueLabel: formatMetricValue(metric.latest, metric.unit),
    changeLabel:
      change === 0
        ? "Flat versus previous reading"
        : `${changePrefix} ${formatMetricValue(Math.abs(change), metric.unit)} versus previous reading`,
    effect,
    weight,
    summary: marketWeatherComponentSummary(metric.id, effect),
    sourceIds: [metric.source.id]
  };
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
  const confidenceTone =
    confidence.overall >= 0.75 ? "fairly solid" : confidence.overall >= 0.6 ? "moderate" : "limited";

  return `In plain English: ${regime.summary} The clearest signals right now are ${strongest}. Confidence is ${confidenceTone} (${confidence.overall.toFixed(2)}) because some of the inputs are still partial or less timely than we would like.`;
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

function directionalWeatherEffect(value: number): ScoreDirection {
  if (value >= 58) {
    return "supportive";
  }
  if (value >= 42) {
    return "neutral";
  }
  return "restrictive";
}

function marketWeatherOutlook(score: number): string {
  if (score >= 72) {
    return "Sunny";
  }
  if (score >= 58) {
    return "Mostly Sunny";
  }
  if (score >= 42) {
    return "Cloudy";
  }
  if (score >= 28) {
    return "Rainy";
  }
  return "Stormy";
}

function marketWeatherComponentSummary(metricId: string, effect: ScoreDirection): string {
  switch (metricId) {
    case "dollarIndex":
    case "DTWEXBGS":
      return effect === "supportive"
        ? "A softer dollar is easing pressure on global risk assets."
        : effect === "restrictive"
          ? "A firmer dollar is acting like a headwind for risk appetite."
          : "Dollar moves are mixed enough to be context rather than a decisive push.";
    case "realYield10y":
    case "DFII10":
      return effect === "supportive"
        ? "Lower real yields make non-yielding assets like Bitcoin easier to hold."
        : effect === "restrictive"
          ? "Higher real yields increase the appeal of cash and bonds over Bitcoin."
          : "Real yields are not moving enough to dominate the current read.";
    case "liquidityProxy":
    case "WALCL":
      return effect === "supportive"
        ? "Liquidity conditions are improving, which usually helps speculative demand."
        : effect === "restrictive"
          ? "Liquidity is tightening, which can drain support from risk assets."
          : "Liquidity is stable enough that it is neither helping nor hurting much.";
    case "riskProxy":
    case "SP500":
      return effect === "supportive"
        ? "Broader risk appetite is constructive and not pushing investors into defense."
        : effect === "restrictive"
          ? "Investors are leaning more defensive across broader markets."
          : "Risk appetite is mixed, so this input should be treated as secondary context.";
    default:
      return "This metric is one of the ingredients behind the broader market weather score.";
  }
}

function buildConfidenceNotes(input: {
  timeliness: number;
  coverage: number;
  agreement: number;
  sources: SourceStamp[];
}): string[] {
  const notes: string[] = [];

  if (input.timeliness < 0.7) {
    notes.push("Some of the supporting data is delayed, simulated, or older than ideal.");
  }

  if (input.coverage < 0.75) {
    notes.push("We can only see part of the large-buyer and macro picture in this MVP.");
  }

  if (input.agreement < 0.7) {
    notes.push("The signals disagree with each other, so this headline read should be treated cautiously.");
  }

  if (notes.length === 0) {
    notes.push("The main inputs are fresh and broadly telling the same story.");
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

function formatMetricValue(value: number, unit: string): string {
  const formatted = new Intl.NumberFormat("en-US", {
    minimumFractionDigits: 0,
    maximumFractionDigits: unit === "%" ? 2 : Math.abs(value) >= 100 ? 1 : 2
  }).format(value);

  if (unit === "%") {
    return `${formatted}%`;
  }

  if (unit === "bn") {
    return `${formatted} bn`;
  }

  return formatted;
}
