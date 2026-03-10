import type {
  DataMode,
  ReplayBucket,
  ReplayRange,
  ReplayTimeline
} from "./contracts.ts";
import type { AppConfig } from "./config.ts";
import { buildDemoReplayFrames, buildReplaySource } from "./fixtures.ts";
import { loadMempoolSignal } from "./providers.ts";
import { buildMempoolScore } from "./scores.ts";

type FetchFn = typeof fetch;

export async function buildReplayTimeline(input: {
  range: ReplayRange;
  bucket: ReplayBucket;
  mode: DataMode;
  config: AppConfig;
  now?: Date;
  fetchImpl?: FetchFn;
}): Promise<ReplayTimeline> {
  const now = input.now ?? new Date();
  const fetchImpl = input.fetchImpl ?? fetch;
  const liveSignal = await loadMempoolSignal(input.mode, input.config, now, fetchImpl);
  const anchor = buildMempoolScore(liveSignal).value;

  return {
    generatedAt: now.toISOString(),
    range: input.range,
    bucket: input.bucket,
    frames: buildDemoReplayFrames(input.range, input.bucket, now, anchor),
    source: buildReplaySource(now)
  };
}
