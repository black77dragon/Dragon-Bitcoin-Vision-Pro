import type { AppConfig } from "./config.ts";
import type { DataMode, RegimeSnapshot } from "./contracts.ts";
import { buildDemoReplayFrames } from "./fixtures.ts";
import { buildMethodologyResponse } from "./methodology.ts";
import { loadFlowSignal, loadMacroSignal, loadMempoolSignal } from "./providers.ts";
import { buildRegimeState, buildScoreBundle } from "./scores.ts";

type FetchFn = typeof fetch;

export async function buildCurrentBriefing(input: {
  mode: DataMode;
  config: AppConfig;
  now?: Date;
  fetchImpl?: FetchFn;
}): Promise<RegimeSnapshot> {
  const now = input.now ?? new Date();
  const fetchImpl = input.fetchImpl ?? fetch;

  const [mempoolSignal, macroSignal, flowSignal] = await Promise.all([
    loadMempoolSignal(input.mode, input.config, now, fetchImpl),
    loadMacroSignal(input.mode, input.config, now, fetchImpl),
    loadFlowSignal(input.mode, input.config, now, fetchImpl)
  ]);

  const scoreBundle = buildScoreBundle({
    mempoolSignal,
    macroSignal,
    flowSignal
  });

  return {
    generatedAt: now.toISOString(),
    regime: buildRegimeState({
      mempoolScore: scoreBundle.mempool.value,
      macroScore: scoreBundle.macro.value,
      flowScore: scoreBundle.flows.value,
      persistenceRatio: mempoolSignal.persistenceRatio
    }),
    confidence: scoreBundle.confidence,
    scores: [scoreBundle.mempool, scoreBundle.macro, scoreBundle.flows],
    evidence: scoreBundle.evidence,
    narrative: scoreBundle.narrative,
    actions: [
      { id: "open-arena", label: "Open Mempool Arena", destination: "vision://arena" },
      { id: "view-replay", label: "Replay 6H", destination: "/v1/mempool/replay?range=6h&bucket=1m" },
      { id: "view-methodology", label: "View Methodology", destination: "/v1/methodology" },
      { id: "save-snapshot", label: "Save Snapshot", destination: "vision://snapshot/save" }
    ],
    sources: dedupeSources([
      ...mempoolSignal.sources,
      ...macroSignal.sources,
      ...flowSignal.sources
    ])
  };
}

export function buildArenaSeedScore(snapshot: RegimeSnapshot): number {
  return snapshot.scores.find((score) => score.key === "mempoolStress")?.value ?? 60;
}

export function buildDemoMethodology(now = new Date()) {
  return buildMethodologyResponse(now);
}

export function buildFallbackReplayAnchor(now = new Date()) {
  return buildDemoReplayFrames("6h", "1m", now).at(-1)?.mempoolStressScore ?? 60;
}

function dedupeSources(sources: RegimeSnapshot["sources"]): RegimeSnapshot["sources"] {
  const map = new Map(sources.map((source) => [source.id, source]));
  return Array.from(map.values());
}
