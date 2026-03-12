import type { DataMode } from "./contracts.ts";

export interface AppConfig {
  port: number;
  mempoolBaseUrl: string;
  fredApiKey?: string;
  macroSignalUrl?: string;
  macroNewsFeedUrls: string[];
  glassnodeApiKey?: string;
  glassnodeBaseUrl: string;
  etfFlowProxyUrl?: string;
  farsideEtfCrossCheckUrl?: string;
  replayStorePath: string;
  defaultMode: DataMode;
}

const DEFAULT_OFFICIAL_MACRO_NEWS_FEEDS = [
  "https://www.federalreserve.gov/feeds/press_monetary.xml",
  "https://www.bls.gov/feed/empsit.rss",
  "https://www.bls.gov/feed/cpi.rss",
  "https://www.bls.gov/feed/ppi.rss"
];

export function readConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  return {
    port: Number(env.PORT ?? "8787"),
    mempoolBaseUrl: env.MEMPOOL_BASE_URL ?? "https://mempool.space",
    fredApiKey: env.FRED_API_KEY || undefined,
    macroSignalUrl: env.MACRO_SIGNAL_URL || undefined,
    macroNewsFeedUrls: readMacroNewsFeedUrls(env.MACRO_NEWS_FEED_URLS),
    glassnodeApiKey: env.GLASSNODE_API_KEY || undefined,
    glassnodeBaseUrl: env.GLASSNODE_BASE_URL ?? "https://api.glassnode.com/",
    etfFlowProxyUrl: env.ETF_FLOW_PROXY_URL || undefined,
    farsideEtfCrossCheckUrl: readOptionalUrl(env.FARSIDE_ETF_CROSSCHECK_URL, "https://farside.co.uk/btc/"),
    replayStorePath: env.REPLAY_STORE_PATH ?? "./data/replay-frames.json",
    defaultMode: normalizeMode(env.DEFAULT_MODE)
  };
}

function normalizeMode(value?: string): DataMode {
  if (value === "demo" || value === "live") {
    return value;
  }

  return "auto";
}

function readMacroNewsFeedUrls(value?: string): string[] {
  if (!value) {
    return [];
  }

  if (value.trim().toLowerCase() === "official") {
    return DEFAULT_OFFICIAL_MACRO_NEWS_FEEDS;
  }

  return value
    .split(/[\n,]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function readOptionalUrl(value: string | undefined, fallback?: string): string | undefined {
  if (!value) {
    return fallback;
  }

  const normalized = value.trim();
  if (!normalized || ["0", "false", "none", "off"].includes(normalized.toLowerCase())) {
    return undefined;
  }

  return normalized;
}
