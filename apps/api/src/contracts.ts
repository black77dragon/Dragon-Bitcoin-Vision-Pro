export type LicenseClass = "A" | "B" | "C";
export type SourceStatus = "live" | "delayed" | "demo" | "stale";
export type ScoreDirection = "supportive" | "neutral" | "restrictive" | "elevated";
export type AlertLevel = "normal" | "watch" | "elevated";
export type RegimeStateKey =
  | "calmAccumulation"
  | "elevatedNetworkStress"
  | "speculativeSpike"
  | "distributionRisk"
  | "structurallyCongested"
  | "mixedEvidence";
export type DataMode = "auto" | "demo" | "live";
export type ReplayRange = "6h" | "24h";
export type ReplayBucket = "1m" | "5m";

export interface SourceStamp {
  id: string;
  name: string;
  licenseClass: LicenseClass;
  cadence: string;
  status: SourceStatus;
  fetchedAt: string;
  publishedAt?: string;
  freshnessSeconds: number;
  confidencePenalty: number;
  note?: string;
}

export interface ScoreCard {
  key: "mempoolStress" | "macroLiquidity" | "knownFlowPressure";
  label: string;
  value: number;
  direction: ScoreDirection;
  summary: string;
  contributionWeight: number;
  sourceIds: string[];
}

export interface EvidenceCard {
  id: string;
  title: string;
  valueLabel: string;
  interpretation: string;
  direction: ScoreDirection;
  weight: number;
  freshnessLabel: string;
  sourceIds: string[];
}

export interface ConfidenceBreakdown {
  overall: number;
  timeliness: number;
  coverage: number;
  agreement: number;
  notes: string[];
}

export interface RegimeState {
  key: RegimeStateKey;
  label: string;
  summary: string;
  alertLevel: AlertLevel;
}

export interface ActionLink {
  id: string;
  label: string;
  destination: string;
}

export interface RegimeSnapshot {
  generatedAt: string;
  regime: RegimeState;
  confidence: ConfidenceBreakdown;
  scores: ScoreCard[];
  evidence: EvidenceCard[];
  narrative: string;
  actions: ActionLink[];
  sources: SourceStamp[];
}

export interface FeeBand {
  label: string;
  minFee: number;
  maxFee: number;
  queuedVBytes: number;
  estimatedBlocksToClear: number;
}

export interface BlockClearance {
  blockHeight: number;
  clearedVBytes: number;
  feeFloorAfter: number;
}

export interface ReplayFrame {
  timestamp: string;
  stateLabel: string;
  mempoolStressScore: number;
  queuedVBytes: number;
  estimatedBlocksToClear: number;
  feeBands: FeeBand[];
  blockClearance?: BlockClearance;
}

export interface ReplayTimeline {
  generatedAt: string;
  range: ReplayRange;
  bucket: ReplayBucket;
  frames: ReplayFrame[];
  source: SourceStamp;
}

export interface MethodologyResponse {
  updatedAt: string;
  scoreWeights: Record<string, Record<string, number>>;
  sourceCatalog: Array<Record<string, string | number | boolean>>;
  freshnessRules: string[];
  limitations: string[];
}
