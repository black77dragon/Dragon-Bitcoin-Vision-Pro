import type { DataMode } from "./contracts.ts";

export interface AppConfig {
  port: number;
  mempoolBaseUrl: string;
  fredApiKey?: string;
  etfFlowProxyUrl?: string;
  defaultMode: DataMode;
}

export function readConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  return {
    port: Number(env.PORT ?? "8787"),
    mempoolBaseUrl: env.MEMPOOL_BASE_URL ?? "https://mempool.space",
    fredApiKey: env.FRED_API_KEY || undefined,
    etfFlowProxyUrl: env.ETF_FLOW_PROXY_URL || undefined,
    defaultMode: normalizeMode(env.DEFAULT_MODE)
  };
}

function normalizeMode(value?: string): DataMode {
  if (value === "demo" || value === "live") {
    return value;
  }

  return "auto";
}
