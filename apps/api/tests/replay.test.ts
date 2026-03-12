import test from "node:test";
import assert from "node:assert/strict";
import { readConfig } from "../src/config.ts";
import type { ReplayFrame } from "../src/contracts.ts";
import { buildReplayTimeline } from "../src/replay.ts";
import type { ReplayFrameStore } from "../src/replay-store.ts";

test("replay uses persisted frames when enough history exists", async () => {
  const now = new Date("2026-03-10T12:00:00Z");
  const store = new InMemoryReplayFrameStore(
    Array.from({ length: 359 }, (_, index) => {
      const minutesBack = 359 - index;
      return makeReplayFrame(new Date(now.getTime() - minutesBack * 60_000), 70 + (index % 4));
    })
  );

  const replay = await buildReplayTimeline({
    range: "6h",
    bucket: "1m",
    mode: "auto",
    config: readConfig({
      PORT: "0",
      MEMPOOL_BASE_URL: "https://mempool.space"
    }),
    now,
    fetchImpl: createMempoolFetchStub(),
    replayStore: store
  });

  assert.equal(replay.frames.length, 360);
  assert.equal(replay.source.id, "replay-store");
  assert.equal(replay.source.status, "live");
  assert.match(replay.source.note ?? "", /persisted rolling snapshots/i);
  assert.equal(replay.frames.at(-1)?.timestamp, now.toISOString());
});

test("replay backfills missing history when persisted coverage is still sparse", async () => {
  const now = new Date("2026-03-10T12:00:00Z");
  const store = new InMemoryReplayFrameStore([
    makeReplayFrame(new Date(now.getTime() - 3 * 60_000), 74),
    makeReplayFrame(new Date(now.getTime() - 2 * 60_000), 76)
  ]);

  const replay = await buildReplayTimeline({
    range: "6h",
    bucket: "1m",
    mode: "auto",
    config: readConfig({
      PORT: "0",
      MEMPOOL_BASE_URL: "https://mempool.space"
    }),
    now,
    fetchImpl: createMempoolFetchStub(),
    replayStore: store
  });

  assert.equal(replay.frames.length, 360);
  assert.equal(replay.source.id, "replay-store");
  assert.equal(replay.source.status, "delayed");
  assert.match(replay.source.note ?? "", /backfill/i);
  assert.equal(replay.frames.at(-1)?.timestamp, now.toISOString());
});

class InMemoryReplayFrameStore implements ReplayFrameStore {
  constructor(private frames: ReplayFrame[] = []) {}

  async append(frame: ReplayFrame): Promise<void> {
    this.frames.push(frame);
  }

  async list(): Promise<ReplayFrame[]> {
    return this.frames
      .slice()
      .sort((left, right) => left.timestamp.localeCompare(right.timestamp));
  }
}

function makeReplayFrame(timestamp: Date, score: number): ReplayFrame {
  return {
    timestamp: timestamp.toISOString(),
    stateLabel: score >= 68 ? "Elevated stress" : "Normal to firm",
    mempoolStressScore: score,
    queuedVBytes: 5_500_000,
    estimatedBlocksToClear: 6.2,
    feeBands: [
      {
        label: "Priority",
        minFee: 25,
        maxFee: 40,
        queuedVBytes: 2_000_000,
        estimatedBlocksToClear: 2.5
      }
    ]
  };
}

function createMempoolFetchStub(): typeof fetch {
  return async (input) => {
    const url = String(input);

    if (url.endsWith("/api/mempool")) {
      return jsonResponse({
        count: 321000,
        vsize: 6_900_000,
        total_fee: 135_000_000
      });
    }

    if (url.endsWith("/api/v1/fees/recommended")) {
      return jsonResponse({
        fastestFee: 45,
        halfHourFee: 36,
        hourFee: 28,
        economyFee: 16,
        minimumFee: 12
      });
    }

    if (url.endsWith("/api/v1/fees/mempool-blocks")) {
      return jsonResponse([
        {
          blockSize: 1_250_000,
          blockVSize: 990_000,
          nTx: 2350,
          totalFees: 2_100_000,
          medianFee: 38,
          feeRange: [12, 18, 26, 38, 45]
        },
        {
          blockSize: 1_180_000,
          blockVSize: 930_000,
          nTx: 2120,
          totalFees: 1_740_000,
          medianFee: 31,
          feeRange: [10, 16, 22, 31, 37]
        }
      ]);
    }

    throw new Error(`Unhandled fetch URL in test: ${url}`);
  };
}

function jsonResponse(payload: unknown): Response {
  return new Response(JSON.stringify(payload), {
    status: 200,
    headers: { "Content-Type": "application/json" }
  });
}
