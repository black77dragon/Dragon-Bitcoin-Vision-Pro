import { buildDemoBitcoinPriceSignal, buildDemoFlowSignal, buildDemoMacroSignal, buildDemoMempoolSignal, buildFeeBands, buildSourceStamp, type BitcoinPriceSignal, type FlowSignal, type MacroSignal, type MempoolSignal, type MetricSignal } from "./fixtures.ts";
import type { AppConfig } from "./config.ts";
import type { DataMode, SourceStatus } from "./contracts.ts";

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

interface MacroSignalFeedResponse {
  publishedAt: string;
  sourceName?: string;
  coverage?: number;
  news?: MacroHeadlineFeedValue[];
  metrics: {
    dollarIndex: MacroMetricFeedValue;
    realYield10y: MacroMetricFeedValue;
    liquidityProxy: MacroMetricFeedValue;
    riskProxy: MacroMetricFeedValue;
  };
}

interface MacroMetricFeedValue {
  latest: number;
  previous: number;
  unit?: string;
  publishedAt?: string;
  sourceName?: string;
  confidencePenalty?: number;
  cadence?: string;
}

interface MacroHeadlineFeedValue {
  title: string;
  publishedAt: string;
  sourceName?: string;
  url?: string;
}

interface EtfFlowFeedResponse {
  publishedAt: string;
  netInflowUsd?: number;
  previousNetInflowUsd?: number;
  coverage?: number;
  expectedFundCount?: number;
  sourceName?: string;
  funds?: EtfFundFlow[];
}

interface EtfFundFlow {
  ticker: string;
  netFlowUsd: number;
  previousNetFlowUsd?: number;
}

interface PriceFeedResponse {
  USD?: number;
  usd?: number;
}

interface GlassnodeMetricPoint {
  t: string | number;
  v: number;
}

interface FarsideEtfCrossCheck {
  publishedAt: Date;
  netFlowUsd: number;
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
  if (mode === "demo") {
    return buildDemoMacroSignal(now);
  }

  if (config.macroSignalUrl) {
    try {
      const signal = await fetchMacroSignalFeed(config.macroSignalUrl, now, fetchImpl);
      return await enrichMacroSignalWithConfiguredNews(signal, config, now, fetchImpl);
    } catch {
      // Fall through to FRED-backed assembly, then to demo if it also fails.
    }
  }

  const seriesDefinitions = [
    { id: "DTWEXBGS", key: "dollarIndex", label: "Dollar Strength", unit: "index" },
    { id: "DFII10", key: "realYield10y", label: "10Y Real Yield", unit: "%" },
    { id: "WALCL", key: "liquidityProxy", label: "Liquidity Proxy", unit: "bn" },
    { id: "SP500", key: "riskProxy", label: "Risk-On Proxy", unit: "index" }
  ] as const;

  const settled = await Promise.allSettled(
    seriesDefinitions.map((definition) =>
      fetchFredMetric(definition.id, definition.label, definition.unit, config.fredApiKey, now, fetchImpl)
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

  return await enrichMacroSignalWithConfiguredNews({
    dollarIndex,
    realYield10y,
    liquidityProxy,
    riskProxy,
    coverage: round(metrics.length / seriesDefinitions.length, 2),
    sources,
    live: metrics.length === seriesDefinitions.length
  }, config, now, fetchImpl);
}

export async function loadFlowSignal(
  mode: DataMode,
  config: AppConfig,
  now = new Date(),
  fetchImpl: FetchFn = fetch
): Promise<FlowSignal> {
  if (mode === "demo") {
    return buildDemoFlowSignal(now);
  }

  if (config.etfFlowProxyUrl) {
    try {
      return await fetchEtfFlowProxySignal(config.etfFlowProxyUrl, now, fetchImpl);
    } catch {
      // Fall through to Glassnode direct fetch when available, then to demo.
    }
  }

  if (config.glassnodeApiKey) {
    try {
      return await fetchGlassnodeFlowSignal(config, now, fetchImpl);
    } catch {
      // Fall through to demo when direct provider fetch fails.
    }
  }

  return buildDemoFlowSignal(now);
}

export async function loadBitcoinPriceSignal(
  mode: DataMode,
  config: AppConfig,
  now = new Date(),
  fetchImpl: FetchFn = fetch
): Promise<BitcoinPriceSignal> {
  if (mode === "demo") {
    return buildDemoBitcoinPriceSignal(now);
  }

  try {
    const currentPayload = await fetchJson<PriceFeedResponse>(fetchImpl, `${config.mempoolBaseUrl}/api/v1/prices`);
    const currentPriceUsd = round(extractUsdPrice(currentPayload), 2);
    let deltaUsd: number | undefined;

    try {
      const previousPayload = await fetchJson<unknown>(
        fetchImpl,
        `${config.mempoolBaseUrl}/api/v1/historical-price?currency=USD&timestamp=${Math.floor(now.getTime() / 1000) - 300}`
      );
      const previousPriceUsd = extractHistoricalUsdPrice(previousPayload);
      if (Number.isFinite(previousPriceUsd)) {
        deltaUsd = round(currentPriceUsd - previousPriceUsd, 2);
      }
    } catch {
      // Delta is best-effort; keep the current quote even if historical lookup fails.
    }

    const source = buildSourceStamp({
      id: "mempool-price",
      name: "mempool.space BTC/USD",
      licenseClass: "A",
      cadence: "near-real-time",
      status: "live",
      fetchedAt: now,
      freshnessSeconds: 0,
      confidencePenalty: 0
    });

    return {
      priceUsd: currentPriceUsd,
      deltaUsd,
      sources: [source],
      live: true
    };
  } catch {
    return buildDemoBitcoinPriceSignal(now);
  }
}

async function fetchFredMetric(
  seriesId: string,
  label: string,
  unit: string,
  apiKey: string | undefined,
  now: Date,
  fetchImpl: FetchFn
): Promise<MetricSignal> {
  if (!apiKey) {
    return fetchFredMetricCsv(seriesId, label, unit, now, fetchImpl);
  }

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

async function fetchFredMetricCsv(
  seriesId: string,
  label: string,
  unit: string,
  now: Date,
  fetchImpl: FetchFn
): Promise<MetricSignal> {
  const url = `https://fred.stlouisfed.org/graph/fredgraph.csv?id=${encodeURIComponent(seriesId)}`;
  const response = await fetchImpl(url);

  if (!response.ok) {
    throw new Error(`Fetch failed for ${url}: ${response.status}`);
  }

  const csv = await response.text();
  const values = parseFredCsvObservations(csv).slice(0, 2);

  if (values.length < 2) {
    throw new Error(`Insufficient FRED CSV observations for ${seriesId}`);
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
    confidencePenalty: freshnessSeconds > 2 * 24 * 3600 ? 0.1 : 0.02,
    note: "Loaded from FRED public CSV."
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

function parseFredCsvObservations(csv: string): Array<{ date: string; value: number }> {
  return csv
    .split(/\r?\n/)
    .slice(1)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const [date, rawValue] = line.split(",", 2);
      return {
        date,
        value: Number(rawValue)
      };
    })
    .filter((entry) => entry.date && Number.isFinite(entry.value))
    .reverse();
}

async function fetchMacroSignalFeed(
  url: string,
  now: Date,
  fetchImpl: FetchFn
): Promise<MacroSignal> {
  const payload = await fetchJson<MacroSignalFeedResponse>(fetchImpl, url);
  const defaultPublishedAt = new Date(payload.publishedAt);
  const sourceName = payload.sourceName ?? "Macro Signal Feed";
  const dollarIndex = mapMacroMetric("dollarIndex", "Dollar Strength", "index", payload.metrics.dollarIndex, defaultPublishedAt, sourceName, now);
  const realYield10y = mapMacroMetric("realYield10y", "10Y Real Yield", "%", payload.metrics.realYield10y, defaultPublishedAt, sourceName, now);
  const liquidityProxy = mapMacroMetric("liquidityProxy", "Liquidity Proxy", "bn", payload.metrics.liquidityProxy, defaultPublishedAt, sourceName, now);
  const riskProxy = mapMacroMetric("riskProxy", "Risk-On Proxy", "index", payload.metrics.riskProxy, defaultPublishedAt, sourceName, now);

  return applyMacroHeadlineSummary({
    dollarIndex,
    realYield10y,
    liquidityProxy,
    riskProxy,
    coverage: clamp(payload.coverage ?? 1, 0.35, 1),
    sources: [dollarIndex.source, realYield10y.source, liquidityProxy.source, riskProxy.source],
    live: [dollarIndex, realYield10y, liquidityProxy, riskProxy].every((metric) => metric.source.status === "live")
  }, summarizeMacroHeadlines(payload.news));
}

async function enrichMacroSignalWithConfiguredNews(
  signal: MacroSignal,
  config: AppConfig,
  now: Date,
  fetchImpl: FetchFn
): Promise<MacroSignal> {
  if (signal.headlineSummary || config.macroNewsFeedUrls.length === 0) {
    return signal;
  }

  try {
    const headlines = await fetchMacroNewsFeedHeadlines(config.macroNewsFeedUrls, now, fetchImpl);
    return applyMacroHeadlineSummary(signal, summarizeMacroHeadlines(headlines));
  } catch {
    return signal;
  }
}

async function fetchMacroNewsFeedHeadlines(
  urls: string[],
  now: Date,
  fetchImpl: FetchFn
): Promise<MacroHeadlineFeedValue[]> {
  const settled = await Promise.allSettled(
    urls.map(async (url) => {
      const response = await fetchImpl(url);
      if (!response.ok) {
        throw new Error(`Fetch failed for ${url}: ${response.status}`);
      }

      const body = await response.text();
      return parseSyndicationFeed(body, url)
        .filter((item) => now.getTime() - new Date(item.publishedAt).getTime() <= 21 * 24 * 3600 * 1000)
        .slice(0, 3);
    })
  );

  return settled
    .flatMap((result) => (result.status === "fulfilled" ? result.value : []))
    .sort((left, right) => new Date(right.publishedAt).getTime() - new Date(left.publishedAt).getTime());
}

function parseSyndicationFeed(xml: string, fallbackUrl: string): MacroHeadlineFeedValue[] {
  const feedTitle = extractFeedTitle(xml) ?? fallbackSourceName(fallbackUrl);
  const blocks = matchTagBlocks(xml, "item");
  const entries = blocks.length > 0 ? blocks : matchTagBlocks(xml, "entry");

  return entries
    .map((entry) => {
      const title = extractTextTag(entry, "title");
      const publishedAt = extractTextTag(entry, "pubDate")
        ?? extractTextTag(entry, "published")
        ?? extractTextTag(entry, "updated");

      if (!title || !publishedAt) {
        return undefined;
      }

      const parsedDate = new Date(publishedAt);
      if (Number.isNaN(parsedDate.getTime())) {
        return undefined;
      }

      return {
        title,
        publishedAt: parsedDate.toISOString(),
        sourceName: feedTitle,
        url: extractLink(entry)
      };
    })
    .filter((item): item is MacroHeadlineFeedValue => Boolean(item));
}

function extractFeedTitle(xml: string): string | undefined {
  return extractTextTag(xml.match(/<channel\b[\s\S]*?<\/channel>/i)?.[0] ?? "", "title")
    ?? extractTextTag(xml.match(/<feed\b[\s\S]*?<\/feed>/i)?.[0] ?? "", "title");
}

function extractTextTag(value: string, tag: string): string | undefined {
  const match = value.match(new RegExp(`<${tag}\\b[^>]*>([\\s\\S]*?)<\\/${tag}>`, "i"));
  const raw = match?.[1];
  if (!raw) {
    return undefined;
  }

  return decodeFeedText(raw);
}

function matchTagBlocks(value: string, tag: string): string[] {
  return Array.from(value.matchAll(new RegExp(`<${tag}\\b[\\s\\S]*?<\\/${tag}>`, "gi")), (match) => match[0]);
}

function extractLink(entry: string): string | undefined {
  const atomHref = entry.match(/<link\b[^>]*href="([^"]+)"/i)?.[1];
  if (atomHref) {
    return decodeFeedText(atomHref);
  }

  const rssLink = extractTextTag(entry, "link");
  return rssLink && /^https?:\/\//i.test(rssLink) ? rssLink : undefined;
}

function decodeFeedText(value: string): string {
  return value
    .replace(/^<!\[CDATA\[/, "")
    .replace(/\]\]>$/, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, "\"")
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, " ")
    .trim();
}

function fallbackSourceName(url: string): string {
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return "Macro News Feed";
  }
}

function summarizeMacroHeadlines(headlines: MacroHeadlineFeedValue[] | undefined): string | undefined {
  if (!headlines?.length) {
    return undefined;
  }

  const topItems = headlines
    .slice()
    .sort((left, right) => new Date(right.publishedAt).getTime() - new Date(left.publishedAt).getTime())
    .slice(0, 2);

  if (topItems.length === 0) {
    return undefined;
  }

  const summary = topItems
    .map((item) => {
      const sourceName = item.sourceName?.trim();
      return sourceName ? `${sourceName}: ${item.title}` : item.title;
    })
    .join(" | ");

  return `Latest macro release headlines: ${summary}.`;
}

function applyMacroHeadlineSummary(signal: MacroSignal, headlineSummary?: string): MacroSignal {
  if (!headlineSummary) {
    return signal;
  }

  return {
    ...signal,
    headlineSummary
  };
}

function mapMacroMetric(
  id: string,
  label: string,
  defaultUnit: string,
  metric: MacroMetricFeedValue,
  defaultPublishedAt: Date,
  defaultSourceName: string,
  now: Date
): MetricSignal {
  const publishedAt = metric.publishedAt ? new Date(metric.publishedAt) : defaultPublishedAt;
  const freshnessSeconds = Math.max(0, Math.round((now.getTime() - publishedAt.getTime()) / 1000));
  const status = inferMacroStatus(freshnessSeconds, metric.cadence);

  return {
    id,
    label,
    latest: assertFiniteNumber(metric.latest, `${id}.latest`),
    previous: assertFiniteNumber(metric.previous, `${id}.previous`),
    unit: metric.unit ?? defaultUnit,
    source: buildSourceStamp({
      id: `macro-feed-${id}`,
      name: metric.sourceName ?? defaultSourceName,
      licenseClass: "B",
      cadence: metric.cadence ?? "daily",
      status,
      fetchedAt: now,
      publishedAt,
      freshnessSeconds,
      confidencePenalty: clamp(metric.confidencePenalty ?? defaultMacroPenalty(status), 0, 0.4)
    })
  };
}

function inferMacroStatus(freshnessSeconds: number, cadence = "daily"): SourceStatus {
  const delayedThreshold = cadence === "weekly" ? 8 * 24 * 3600 : 2 * 24 * 3600;
  const staleThreshold = cadence === "weekly" ? 15 * 24 * 3600 : 5 * 24 * 3600;

  if (freshnessSeconds > staleThreshold) {
    return "stale";
  }
  if (freshnessSeconds > delayedThreshold) {
    return "delayed";
  }
  return "live";
}

function defaultMacroPenalty(status: SourceStatus): number {
  if (status === "stale") {
    return 0.2;
  }
  if (status === "delayed") {
    return 0.08;
  }
  return 0.02;
}

async function fetchEtfFlowProxySignal(
  url: string,
  now: Date,
  fetchImpl: FetchFn
): Promise<FlowSignal> {
  const payload = await fetchJson<EtfFlowFeedResponse>(fetchImpl, url);
  const publishedAt = new Date(payload.publishedAt);
  const freshnessSeconds = Math.max(0, Math.round((now.getTime() - publishedAt.getTime()) / 1000));
  const netEtfFlowUsd = assertFiniteNumber(
    payload.netInflowUsd ?? sumFundFlows(payload.funds, "netFlowUsd"),
    "etfFlow.netInflowUsd"
  );
  const previousNetEtfFlowUsd =
    assertFiniteNumber(
      payload.previousNetInflowUsd
      ?? sumFundFlows(payload.funds, "previousNetFlowUsd")
      ?? netEtfFlowUsd * 0.7,
      "etfFlow.previousNetInflowUsd"
    );
  const coverage = deriveFlowCoverage(payload);
  const source = buildSourceStamp({
    id: "etf-flow-proxy",
    name: payload.sourceName ?? "ETF Flow Proxy",
    licenseClass: "B",
    cadence: "daily",
    status: inferDailyStatus(freshnessSeconds),
    fetchedAt: now,
    publishedAt,
    freshnessSeconds,
    confidencePenalty: freshnessSeconds > 36 * 3600 ? 0.28 : coverage < 0.75 ? 0.12 : 0.04
  });

  return {
    netEtfFlowUsd,
    previousNetEtfFlowUsd,
    coverage,
    sources: [source],
    live: true
  };
}

async function fetchGlassnodeFlowSignal(
  config: AppConfig,
  now: Date,
  fetchImpl: FetchFn
): Promise<FlowSignal> {
  const url = new URL("v1/metrics/institutions/us_spot_etf_flows_net", config.glassnodeBaseUrl);
  url.searchParams.set("a", "BTC");
  url.searchParams.set("c", "USD");
  url.searchParams.set("i", "24h");
  url.searchParams.set("timestamp_format", "humanized");
  url.searchParams.set("api_key", config.glassnodeApiKey!);

  const points = normalizeMetricPoints(
    await fetchJson<GlassnodeMetricPoint[]>(fetchImpl, url.toString()),
    "Glassnode us_spot_etf_flows_net"
  );
  const latestPoint = points[0];
  const previousPoint = points[1];
  const freshnessSeconds = Math.max(0, Math.round((now.getTime() - latestPoint.publishedAt.getTime()) / 1000));
  const crossCheckNote = await fetchFarsideCrossCheckNote(config, latestPoint, now, fetchImpl);
  const source = buildSourceStamp({
    id: "glassnode-etf-flows",
    name: "Glassnode US Spot BTC ETF Flows",
    licenseClass: "B",
    cadence: "daily",
    status: inferDailyStatus(freshnessSeconds),
    fetchedAt: now,
    publishedAt: latestPoint.publishedAt,
    freshnessSeconds,
    confidencePenalty: freshnessSeconds > 36 * 3600 ? 0.2 : 0.04,
    note: crossCheckNote
  });

  return {
    netEtfFlowUsd: latestPoint.value,
    previousNetEtfFlowUsd: previousPoint.value,
    coverage: 1,
    sources: [source],
    live: true
  };
}

async function fetchFarsideCrossCheckNote(
  config: AppConfig,
  latestPoint: { publishedAt: Date; value: number },
  now: Date,
  fetchImpl: FetchFn
): Promise<string | undefined> {
  if (!config.farsideEtfCrossCheckUrl) {
    return undefined;
  }

  try {
    const crossCheck = await fetchFarsideEtfCrossCheck(config.farsideEtfCrossCheckUrl, fetchImpl);
    const dateLabel = latestPoint.publishedAt.toISOString().slice(0, 10);
    const crossCheckLabel = crossCheck.publishedAt.toISOString().slice(0, 10);
    const deltaUsd = Math.round(crossCheck.netFlowUsd - latestPoint.value);

    if (crossCheckLabel !== dateLabel) {
      return `Farside cross-check is on ${crossCheckLabel}; Glassnode latest is ${dateLabel}.`;
    }

    if (Math.abs(deltaUsd) <= 5_000_000) {
      return `Farside cross-check matched the latest daily total within ${formatUsd(Math.abs(deltaUsd))}.`;
    }

    const freshnessSeconds = Math.max(0, Math.round((now.getTime() - crossCheck.publishedAt.getTime()) / 1000));
    if (freshnessSeconds > 36 * 3600) {
      return `Farside cross-check differs by ${formatUsd(Math.abs(deltaUsd))}, but the comparison row is stale.`;
    }

    return `Farside cross-check differs from Glassnode by ${formatUsd(Math.abs(deltaUsd))}.`;
  } catch {
    return undefined;
  }
}

async function fetchFarsideEtfCrossCheck(
  url: string,
  fetchImpl: FetchFn
): Promise<FarsideEtfCrossCheck> {
  const response = await fetchImpl(url);
  if (!response.ok) {
    throw new Error(`Fetch failed for ${url}: ${response.status}`);
  }

  const body = await response.text();
  const rows = matchTagBlocks(body, "tr");

  for (const row of rows) {
    const cells = Array.from(
      row.matchAll(/<t[dh]\b[^>]*>([\s\S]*?)<\/t[dh]>/gi),
      (match) => decodeFeedText(match[1]).replace(/\u00a0/g, " ").trim()
    );

    if (cells.length < 2) {
      continue;
    }

    const publishedAt = parseFarsideDate(cells[0]);
    const totalCell = cells[cells.length - 1];
    const netFlowUsd = parseFarsideUsdMillions(totalCell);

    if (!publishedAt || netFlowUsd === undefined) {
      continue;
    }

    return {
      publishedAt,
      netFlowUsd
    };
  }

  throw new Error(`Could not parse Farside ETF cross-check from ${url}`);
}

async function fetchJson<T>(fetchImpl: FetchFn, url: string): Promise<T> {
  const response = await fetchImpl(url);

  if (!response.ok) {
    throw new Error(`Fetch failed for ${url}: ${response.status}`);
  }

  return (await response.json()) as T;
}

function deriveFlowCoverage(payload: EtfFlowFeedResponse): number {
  if (payload.coverage !== undefined) {
    return clamp(payload.coverage, 0.35, 1);
  }

  if (payload.funds?.length) {
    const expectedCount = payload.expectedFundCount ?? payload.funds.length;
    return clamp(payload.funds.length / Math.max(expectedCount, 1), 0.35, 1);
  }

  return 0.75;
}

function normalizeMetricPoints(
  points: GlassnodeMetricPoint[],
  label: string
): Array<{ publishedAt: Date; value: number }> {
  const normalized = points
    .map((point) => ({
      publishedAt: parseMetricTimestamp(point.t),
      value: Number(point.v)
    }))
    .filter(
      (point): point is { publishedAt: Date; value: number } =>
        point.publishedAt instanceof Date
        && !Number.isNaN(point.publishedAt.getTime())
        && Number.isFinite(point.value)
    )
    .sort((left, right) => right.publishedAt.getTime() - left.publishedAt.getTime())
    .slice(0, 2);

  if (normalized.length < 2) {
    throw new Error(`Insufficient observations for ${label}`);
  }

  return normalized;
}

function parseMetricTimestamp(value: string | number): Date {
  if (typeof value === "number" && Number.isFinite(value)) {
    const millis = value > 1_000_000_000_000 ? value : value * 1000;
    return new Date(millis);
  }

  return new Date(String(value));
}

function inferDailyStatus(freshnessSeconds: number): SourceStatus {
  if (freshnessSeconds > 36 * 3600) {
    return "stale";
  }

  if (freshnessSeconds > 6 * 3600) {
    return "delayed";
  }

  return "live";
}

function sumFundFlows(
  funds: EtfFundFlow[] | undefined,
  key: "netFlowUsd" | "previousNetFlowUsd"
): number | undefined {
  if (!funds?.length) {
    return undefined;
  }

  const values = funds
    .map((fund) => fund[key])
    .filter((value): value is number => typeof value === "number" && Number.isFinite(value));

  if (values.length === 0) {
    return undefined;
  }

  return values.reduce((sum, value) => sum + value, 0);
}

function assertFiniteNumber(value: number, label: string): number {
  if (!Number.isFinite(value)) {
    throw new Error(`Invalid numeric value for ${label}`);
  }

  return value;
}

function parseFarsideDate(value: string): Date | undefined {
  const normalized = value.replace(/,+/g, " ").replace(/\s+/g, " ").trim();
  const parsed = new Date(`${normalized} 00:00:00 UTC`);
  if (Number.isNaN(parsed.getTime())) {
    return undefined;
  }

  return parsed;
}

function parseFarsideUsdMillions(value: string): number | undefined {
  const normalized = value.trim();
  if (!normalized || normalized === "-" || normalized.toLowerCase() === "nan") {
    return undefined;
  }

  const negative = normalized.startsWith("(") && normalized.endsWith(")");
  const numeric = Number(normalized.replace(/[(),$m\s]/gi, "").replace(/,/g, ""));
  if (!Number.isFinite(numeric)) {
    return undefined;
  }

  return Math.round((negative ? -numeric : numeric) * 1_000_000);
}

function formatUsd(value: number): string {
  const absolute = Math.abs(value);
  if (absolute >= 1_000_000_000) {
    return `$${round(absolute / 1_000_000_000, 2)}B`;
  }
  if (absolute >= 1_000_000) {
    return `$${round(absolute / 1_000_000, 1)}M`;
  }
  if (absolute >= 1_000) {
    return `$${round(absolute / 1_000, 1)}K`;
  }

  return `$${round(absolute, 0)}`;
}

function extractUsdPrice(payload: PriceFeedResponse): number {
  const price = payload.USD ?? payload.usd;
  return assertFiniteNumber(price ?? Number.NaN, "btcPrice.USD");
}

function extractHistoricalUsdPrice(payload: unknown): number {
  const visited = new Set<unknown>();
  const price = findPriceLikeValue(payload, visited);
  return assertFiniteNumber(price ?? Number.NaN, "btcPrice.historicalUsd");
}

function findPriceLikeValue(payload: unknown, visited: Set<unknown>): number | undefined {
  if (typeof payload === "number" && Number.isFinite(payload)) {
    return payload;
  }

  if (typeof payload === "string") {
    const parsed = Number(payload);
    return Number.isFinite(parsed) ? parsed : undefined;
  }

  if (!payload || typeof payload !== "object" || visited.has(payload)) {
    return undefined;
  }

  visited.add(payload);

  if (Array.isArray(payload)) {
    for (const entry of payload) {
      const found = findPriceLikeValue(entry, visited);
      if (found !== undefined) {
        return found;
      }
    }
    return undefined;
  }

  const record = payload as Record<string, unknown>;
  for (const key of ["USD", "usd", "price", "amount", "value", "close", "last", "rate"]) {
    const found = findPriceLikeValue(record[key], visited);
    if (found !== undefined) {
      return found;
    }
  }

  for (const key of ["data", "result", "prices", "price", "history", "values"]) {
    const found = findPriceLikeValue(record[key], visited);
    if (found !== undefined) {
      return found;
    }
  }

  return undefined;
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function round(value: number, decimals: number): number {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}
