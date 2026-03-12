import test from "node:test";
import assert from "node:assert/strict";
import { buildDemoFlowSignal, buildDemoMacroSignal, buildDemoMempoolSignal } from "../src/fixtures.ts";
import {
  buildConfidence,
  buildFlowScore,
  buildMarketWeatherDetail,
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

test("market weather detail exposes four weighted ingredients", () => {
  const signal = buildDemoMacroSignal();
  const score = buildMacroScore(signal);
  const detail = buildMarketWeatherDetail(signal, score);

  assert.equal(detail.outlook, "Mostly Sunny");
  assert.equal(detail.components.length, 4);
  assert.equal(detail.components[0]?.title, "Dollar Strength");
  assert.equal(detail.components.reduce((sum, component) => sum + component.weight, 0), 1);
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
  assert.ok(confidence.notes.some((note) => /delayed|simulated|partial|older/i.test(note)));
});
