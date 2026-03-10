import { buildDemoFlowSignal, buildDemoMacroSignal, buildDemoMempoolSignal, buildFeeBands, buildSourceStamp, type FlowSignal, type MacroSignal, type MempoolSignal, type MetricSignal } from "./fixtures.ts";
import type { AppConfig } from "./config.ts";
import type { DataMode, SourceStamp } from "./contracts.ts";

interface MempoolStatsResponse {
  count: number;
  vsize: number;
  total_fee: number;
}

interface FeeRecommendationResponse {
  fastestFee: number;
  halfHourFee: number;
  hourFee: number;
  economyFee: number;
  minimumFee: number;
}

interface MempoolBlockResponse {
  blockSize: number;
  blockVSize: number;
  nTx: number;
  totalFees: number;
  medianFee: number;
  feeRange: number[];
}

interface FredObservation {
  date: string;
  value: string;
}

interface FredResponse {
  observations: FredObservation[];
}

type FetchFn = typeof fetch;

export async function loadMempoolSignal(
  mode: DataMode,
  config: AppConfig,
  now = new Date(),
  fetchImpl: FetchFn = fetch
): Promise<MempoolSignal> {
  if (mode === "demo") {
    return buildDemoMempoolSignal(now);
  }

  try {
    const [mempool, fees, blocks] = await Promise.all([
      fetchJson<MempoolStatsResponse>(fetchImpl, `${config.mempoolBaseUrl}/api/mempool`),
      fetchJson<FeeRecommendationResponse>(fetchImpl, `${config.mempoolBaseUrl}/api/v1/fees/recommended`),
      fetchJson<MempoolBlockResponse[]>(fetchImpl, `${config.mempoolBaseUrl}/api/v1/fees/mempool-blocks`)
    ]);

    const firstBlock = blocks[0];
    const feeFloor = clamp(Math.max(fees.minimumFee, firstBlock?.feeRange?.[0] ?? fees.minimumFee), 1, 200);
    const stressBand = clamp(Math.max(fees.fastestFee, firstBlock?.medianFee ?? fees.fastestFee), 2, 300);
    const estimatedBlocksToClear = clamp(Math.max(blocks.length, mempool.vsize / 1_000_000), 1, 12);
    const persistenceRatio = clamp((feeFloor + (firstBlock?.medianFee ?? feeFloor)) / 90, 0.1, 1);
    const refillRatio = clamp(
      ((blocks[0]?.blockVSize ?? 900_000) + (blocks[1]?.blockVSize ?? 750_000)) / 2 / 1_000_000,
      0.15,
      1
    );
    const source = buildSourceStamp({
      id: "mempool-space",
      name: "mempool.space",
      licenseClass: "A",
      cadence: "near-real-time",
      status: "live",
      fetchedAt: now,
      freshnessSeconds: 0,
      confidencePenalty: 0
    });

    return {
      minFee: feeFloor,
      fastestFee: stressBand,
      queuedVBytes: mempool.vsize,
      estimatedBlocksToClear: round(estimatedBlocksToClear, 1),
      persistenceRatio: round(persistenceRatio, 2),
      refillRatio: round(refillRatio, 2),
      feeBands: buildFeeBands(mempool.vsize, feeFloor, stressBand),
      sources: [source],
      live: true
    };
  } catch {
    return buildDemoMempoolSignal(now);
  }
}

export async function loadMacroSignal(
  mode: DataMode,
  config: AppConfig,
  now = new Date(),
  fetchImpl: FetchFn = fetch
): Promise<MacroSignal> {
  if (mode === "demo" || !config.fredApiKey) {
    return buildDemoMacroSignal(now);
  }

  const seriesDefinitions = [
    { id: "DTWEXBGS", key: "dollarIndex", label: "Dollar Strength", unit: "index" },
    { id: "DFII10", key: "realYield10y", label: "10Y Real Yield", unit: "%" },
    { id: "WALCL", key: "liquidityProxy", label: "Liquidity Proxy", unit: "bn" },
    { id: "SP500", key: "riskProxy", label: "Risk-On Proxy", unit: "index" }
  ] as const;

  const settled = await Promise.allSettled(
    seriesDefinitions.map((definition) =>
      fetchFredMetric(definition.id, definition.label, definition.unit, config.fredApiKey!, now, fetchImpl)
    )
  );

  const metrics = settled.flatMap((result) => (result.status === "fulfilled" ? [result.value] : []));

  if (metrics.length === 0) {
    return buildDemoMacroSignal(now);
  }

  const demo = buildDemoMacroSignal(now);
  const metricMap = new Map(metrics.map((metric) => [metric.id, metric]));

  const dollarIndex = metricMap.get("DTWEXBGS") ?? demo.dollarIndex;
  const realYield10y = metricMap.get("DFII10") ?? demo.realYield10y;
  const liquidityProxy = metricMap.get("WALCL") ?? demo.liquidityProxy;
  const riskProxy = metricMap.get("SP500") ?? demo.riskProxy;

  const sources = [dollarIndex.source, realYield10y.source, liquidityProxy.source, riskProxy.source];

  return {
    dollarIndex,
    realYield10y,
    liquidityProxy,
    riskProxy,
    coverage: round(metrics.length / seriesDefinitions.length, 2),
    sources,
    live: metrics.length === seriesDefinitions.length
  };
}

export async function loadFlowSignal(
  mode: DataMode,
  config: AppConfig,
  now = new Date(),
  fetchImpl: FetchFn = fetch
): Promise<FlowSignal> {
  if (mode === "demo" || !config.etfFlowProxyUrl) {
    return buildDemoFlowSignal(now);
  }

  try {
    const payload = await fetchJson<{
      publishedAt: string;
      netInflowUsd: number;
      previousNetInflowUsd?: number;
      coverage?: number;
      sourceName?: string;
    }>(fetchImpl, config.etfFlowProxyUrl);
    const publishedAt = new Date(payload.publishedAt);
    const freshnessSeconds = Math.max(0, Math.round((now.getTime() - publishedAt.getTime()) / 1000));
    const source = buildSourceStamp({
      id: "etf-flow-proxy",
      name: payload.sourceName ?? "ETF Flow Proxy",
      licenseClass: "B",
      cadence: "daily",
      status: freshnessSeconds > 36 * 3600 ? "stale" : "delayed",
      fetchedAt: now,
      publishedAt,
      freshnessSeconds,
      confidencePenalty: freshnessSeconds > 36 * 3600 ? 0.28 : 0.08
    });

    return {
      netEtfFlowUsd: payload.netInflowUsd,
      previousNetEtfFlowUsd: payload.previousNetInflowUsd ?? payload.netInflowUsd * 0.7,
      coverage: clamp(payload.coverage ?? 0.75, 0.35, 1),
      sources: [source],
      live: true
    };
  } catch {
    return buildDemoFlowSignal(now);
  }
}

async function fetchFredMetric(
  seriesId: string,
  label: string,
  unit: string,
  apiKey: string,
  now: Date,
  fetchImpl: FetchFn
): Promise<MetricSignal> {
  const url = new URL("https://api.stlouisfed.org/fred/series/observations");
  url.searchParams.set("series_id", seriesId);
  url.searchParams.set("api_key", apiKey);
  url.searchParams.set("file_type", "json");
  url.searchParams.set("sort_order", "desc");
  url.searchParams.set("limit", "2");

  const response = await fetchJson<FredResponse>(fetchImpl, url.toString());
  const values = response.observations
    .map((observation) => ({
      date: observation.date,
      value: Number(observation.value)
    }))
    .filter((observation) => Number.isFinite(observation.value))
    .slice(0, 2);

  if (values.length < 2) {
    throw new Error(`Insufficient FRED observations for ${seriesId}`);
  }

  const publishedAt = new Date(`${values[0].date}T00:00:00Z`);
  const freshnessSeconds = Math.max(0, Math.round((now.getTime() - publishedAt.getTime()) / 1000));
  const source = buildSourceStamp({
    id: seriesId,
    name: `FRED ${label}`,
    licenseClass: "B",
    cadence: seriesId === "WALCL" ? "weekly" : "daily",
    status: freshnessSeconds > 2 * 24 * 3600 ? "delayed" : "live",
    fetchedAt: now,
    publishedAt,
    freshnessSeconds,
    confidencePenalty: freshnessSeconds > 2 * 24 * 3600 ? 0.1 : 0.02
  });

  return {
    id: seriesId,
    label,
    latest: values[0].value,
    previous: values[1].value,
    unit,
    source
  };
}

async function fetchJson<T>(fetchImpl: FetchFn, url: string): Promise<T> {
  const response = await fetchImpl(url);

  if (!response.ok) {
    throw new Error(`Fetch failed for ${url}: ${response.status}`);
  }

  return (await response.json()) as T;
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function round(value: number, decimals: number): number {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}
