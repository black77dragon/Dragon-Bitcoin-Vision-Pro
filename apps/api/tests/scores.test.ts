import test from "node:test";
import assert from "node:assert/strict";
import { buildDemoFlowSignal, buildDemoMacroSignal, buildDemoMempoolSignal } from "../src/fixtures.ts";
import {
  buildConfidence,
  buildFlowScore,
  buildMacroScore,
  buildMempoolScore,
  buildRegimeState
} from "../src/scores.ts";

test("mempool score emphasizes persistent congestion", () => {
  const signal = buildDemoMempoolSignal();
  const score = buildMempoolScore(signal);

  assert.equal(score.key, "mempoolStress");
  assert.ok(score.value > 60);
  assert.equal(score.direction, "elevated");
});

test("macro score stays supportive when demo inputs ease", () => {
  const signal = buildDemoMacroSignal();
  const score = buildMacroScore(signal);

  assert.equal(score.key, "macroLiquidity");
  assert.ok(score.value >= 50);
  assert.equal(score.direction, "supportive");
});

test("composite regime reaches structural congestion on aligned demand", () => {
  const mempool = buildMempoolScore(buildDemoMempoolSignal()).value;
  const macro = buildMacroScore(buildDemoMacroSignal()).value;
  const flows = buildFlowScore(buildDemoFlowSignal()).value;

  const regime = buildRegimeState({
    mempoolScore: 84,
    macroScore: macro,
    flowScore: flows,
    persistenceRatio: 0.72
  });

  assert.equal(regime.key, "structurallyCongested");
  assert.equal(regime.alertLevel, "elevated");
  assert.ok(mempool > 60);
});

test("confidence degrades when sources are demo-backed", () => {
  const mempool = buildDemoMempoolSignal();
  const macro = buildDemoMacroSignal();
  const flows = buildDemoFlowSignal();

  const confidence = buildConfidence(
    [...mempool.sources, ...macro.sources, ...flows.sources],
    [0.82, macro.coverage, flows.coverage],
    [72, 61, 58]
  );

  assert.ok(confidence.overall < 0.85);
  assert.ok(confidence.notes.some((note) => note.includes("demo")));
});
