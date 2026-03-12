import type {
  ReplayFrame,
  DataMode,
  ReplayBucket,
  ReplayRange,
  ReplayTimeline
} from "./contracts.ts";
import type { AppConfig } from "./config.ts";
import { buildDemoReplayFrames, buildReplaySource, buildSourceStamp } from "./fixtures.ts";
import { loadMempoolSignal } from "./providers.ts";
import { buildMempoolScore } from "./scores.ts";
import { createReplayFrameStore, type ReplayFrameStore } from "./replay-store.ts";

type FetchFn = typeof fetch;

export async function buildReplayTimeline(input: {
  range: ReplayRange;
  bucket: ReplayBucket;
  mode: DataMode;
  config: AppConfig;
  now?: Date;
  fetchImpl?: FetchFn;
  replayStore?: ReplayFrameStore;
}): Promise<ReplayTimeline> {
  const now = input.now ?? new Date();
  const fetchImpl = input.fetchImpl ?? fetch;

  if (input.mode === "demo") {
    return {
      generatedAt: now.toISOString(),
      range: input.range,
      bucket: input.bucket,
      frames: buildDemoReplayFrames(input.range, input.bucket, now),
      source: buildReplaySource(now)
    };
  }

  const liveSignal = await loadMempoolSignal(input.mode, input.config, now, fetchImpl);
  const currentFrame = buildCurrentReplayFrame(liveSignal, now);
  const store = input.replayStore ?? createReplayFrameStore(input.config);
  await store.append(currentFrame);
  const persistedFrames = await store.list();
  const replayFrames = buildReplayFrames({
    persistedFrames,
    range: input.range,
    bucket: input.bucket,
    now,
    anchor: currentFrame.mempoolStressScore
  });

  return {
    generatedAt: now.toISOString(),
    range: input.range,
    bucket: input.bucket,
    frames: replayFrames.frames,
    source: replayFrames.source
  };
}

function buildCurrentReplayFrame(
  signal: Awaited<ReturnType<typeof loadMempoolSignal>>,
  now: Date
): ReplayFrame {
  const score = buildMempoolScore(signal).value;

  return {
    timestamp: now.toISOString(),
    stateLabel: stateLabelForScore(score),
    mempoolStressScore: score,
    queuedVBytes: signal.queuedVBytes,
    estimatedBlocksToClear: signal.estimatedBlocksToClear,
    feeBands: signal.feeBands
  };
}

function buildReplayFrames(input: {
  persistedFrames: ReplayFrame[];
  range: ReplayRange;
  bucket: ReplayBucket;
  now: Date;
  anchor: number;
}): { frames: ReplayFrame[]; source: ReplayTimeline["source"] } {
  const rangeMinutes = input.range === "24h" ? 24 * 60 : 6 * 60;
  const bucketMinutes = input.bucket === "5m" ? 5 : 1;
  const expectedCount = Math.floor(rangeMinutes / bucketMinutes);
  const windowStart = new Date(input.now.getTime() - rangeMinutes * 60_000);
  const persistedWindow = input.persistedFrames.filter((frame) => new Date(frame.timestamp) >= windowStart);
  const bucketedPersistedFrames = bucketizeFrames(persistedWindow, bucketMinutes);

  if (bucketedPersistedFrames.length >= expectedCount) {
    return {
      frames: bucketedPersistedFrames.slice(-expectedCount),
      source: buildReplayStoreSource(input.now, {
        persistedFrameCount: bucketedPersistedFrames.length,
        expectedFrameCount: expectedCount,
        usedBackfill: false
      })
    };
  }

  const demoFrames = buildDemoReplayFrames(input.range, input.bucket, input.now, input.anchor);
  const mergedFrames = dedupeFrames([...demoFrames, ...bucketedPersistedFrames]).slice(-expectedCount);

  return {
    frames: mergedFrames,
    source: buildReplayStoreSource(input.now, {
      persistedFrameCount: bucketedPersistedFrames.length,
      expectedFrameCount: expectedCount,
      usedBackfill: true
    })
  };
}

function bucketizeFrames(frames: ReplayFrame[], bucketMinutes: number): ReplayFrame[] {
  if (bucketMinutes === 1) {
    return dedupeFrames(frames);
  }

  const buckets = new Map<number, ReplayFrame>();

  for (const frame of dedupeFrames(frames)) {
    const timestamp = new Date(frame.timestamp);
    const bucketKey = Math.floor(timestamp.getTime() / (bucketMinutes * 60_000));
    buckets.set(bucketKey, frame);
  }

  return Array.from(buckets.values()).sort((left, right) => left.timestamp.localeCompare(right.timestamp));
}

function dedupeFrames(frames: ReplayFrame[]): ReplayFrame[] {
  const map = new Map<string, ReplayFrame>();

  for (const frame of frames) {
    map.set(frame.timestamp, frame);
  }

  return Array.from(map.values()).sort((left, right) => left.timestamp.localeCompare(right.timestamp));
}

function buildReplayStoreSource(
  now: Date,
  input: {
    persistedFrameCount: number;
    expectedFrameCount: number;
    usedBackfill: boolean;
  }
): ReplayTimeline["source"] {
  const coverage = Math.min(input.persistedFrameCount / Math.max(input.expectedFrameCount, 1), 1);

  return buildSourceStamp({
    id: "replay-store",
    name: input.usedBackfill ? "Replay Snapshot Store (with backfill)" : "Replay Snapshot Store",
    licenseClass: "A",
    cadence: "1m rolling snapshots",
    status: input.usedBackfill ? "delayed" : "live",
    fetchedAt: now,
    freshnessSeconds: 0,
    confidencePenalty: input.usedBackfill ? round((1 - coverage) * 0.18, 2) : 0.02,
    note: input.usedBackfill
      ? "Persisted replay is active; demo backfill fills older gaps until enough history accumulates."
      : "Replay is sourced from persisted rolling snapshots."
  });
}

function stateLabelForScore(score: number): string {
  if (score >= 80) {
    return "Structural congestion";
  }
  if (score >= 68) {
    return "Elevated stress";
  }
  if (score >= 52) {
    return "Normal to firm";
  }
  return "Calm";
}

function round(value: number, decimals: number): number {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}
