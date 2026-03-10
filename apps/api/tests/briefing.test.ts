import test from "node:test";
import assert from "node:assert/strict";
import { buildCurrentBriefing } from "../src/briefing.ts";
import { readConfig } from "../src/config.ts";
import { handleApiRequest } from "../src/server.ts";

test("briefing endpoint assembles a complete snapshot in demo mode", async () => {
  const snapshot = await buildCurrentBriefing({
    mode: "demo",
    config: readConfig({
      PORT: "8787",
      MEMPOOL_BASE_URL: "https://mempool.space"
    })
  });

  assert.equal(snapshot.scores.length, 3);
  assert.equal(snapshot.evidence.length, 3);
  assert.ok(snapshot.sources.length >= 3);
  assert.ok(snapshot.actions.some((action) => action.id === "open-arena"));
});

test("server exposes briefing, replay, and methodology routes", async () => {
  const config = readConfig({
    PORT: "0",
    MEMPOOL_BASE_URL: "https://mempool.space",
    DEFAULT_MODE: "demo"
  });

  const [briefing, replay, methodology] = await Promise.all([
    handleApiRequest({
      url: new URL("http://localhost/v1/briefing/current?mode=demo"),
      config
    }),
    handleApiRequest({
      url: new URL("http://localhost/v1/mempool/replay?range=6h&bucket=1m&mode=demo"),
      config
    }),
    handleApiRequest({
      url: new URL("http://localhost/v1/methodology"),
      config
    })
  ]);

  assert.equal(briefing.statusCode, 200);
  assert.equal((briefing.body as { regime: { label: string } }).regime.label.length > 0, true);
  assert.equal(replay.statusCode, 200);
  assert.equal((replay.body as { range: string }).range, "6h");
  assert.equal((replay.body as { bucket: string }).bucket, "1m");
  assert.ok((replay.body as { frames: unknown[] }).frames.length >= 300);
  assert.ok(Array.isArray((methodology.body as { limitations: unknown[] }).limitations));
});
