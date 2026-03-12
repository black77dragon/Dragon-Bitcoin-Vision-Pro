import test from "node:test";
import assert from "node:assert/strict";
import { readConfig } from "../src/config.ts";
import { loadBitcoinPriceSignal, loadFlowSignal, loadMacroSignal } from "../src/providers.ts";

test("macro signal prefers a configured production feed", async () => {
  const now = new Date("2026-03-10T12:00:00Z");
  const requestedUrls: string[] = [];
  const config = readConfig({
    PORT: "0",
    MEMPOOL_BASE_URL: "https://mempool.space",
    MACRO_SIGNAL_URL: "https://feeds.example.com/macro",
    FRED_API_KEY: "unused-when-feed-succeeds"
  });

  const signal = await loadMacroSignal("auto", config, now, async (input) => {
    requestedUrls.push(String(input));
    return new Response(
      JSON.stringify({
        publishedAt: "2026-03-10T11:00:00Z",
        sourceName: "Macro Composite Feed",
        coverage: 0.95,
        news: [
          {
            title: "Fed releases March policy statement",
            publishedAt: "2026-03-10T10:30:00Z",
            sourceName: "Federal Reserve"
          }
        ],
        metrics: {
          dollarIndex: { latest: 122.4, previous: 123.1 },
          realYield10y: { latest: 1.61, previous: 1.66, unit: "%" },
          liquidityProxy: { latest: 7248, previous: 7220, unit: "bn", cadence: "weekly" },
          riskProxy: { latest: 5275, previous: 5228 }
        }
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  });

  assert.deepEqual(requestedUrls, ["https://feeds.example.com/macro"]);
  assert.equal(signal.coverage, 0.95);
  assert.equal(signal.live, true);
  assert.equal(signal.dollarIndex.latest, 122.4);
  assert.equal(signal.sources[0]?.name, "Macro Composite Feed");
  assert.equal(signal.headlineSummary, "Latest macro release headlines: Federal Reserve: Fed releases March policy statement.");
});

test("macro signal can enrich public FRED CSV inputs with configured RSS headlines", async () => {
  const now = new Date("2026-03-10T12:00:00Z");
  const requestedUrls: string[] = [];
  const config = readConfig({
    PORT: "0",
    MEMPOOL_BASE_URL: "https://mempool.space",
    MACRO_NEWS_FEED_URLS: "https://www.federalreserve.gov/feeds/press_monetary.xml,https://www.bls.gov/feed/cpi.rss"
  });

  const signal = await loadMacroSignal("auto", config, now, async (input) => {
    const url = String(input);
    requestedUrls.push(url);

    if (url.startsWith("https://fred.stlouisfed.org/graph/fredgraph.csv?id=")) {
      const parsed = new URL(url);
      const seriesId = parsed.searchParams.get("id");
      const valuesBySeries = new Map([
        ["DTWEXBGS", ["122.4", "123.1"]],
        ["DFII10", ["1.61", "1.66"]],
        ["WALCL", ["7248", "7220"]],
        ["SP500", ["5275", "5228"]]
      ]);
      const [latest, previous] = valuesBySeries.get(seriesId ?? "") ?? ["0", "0"];

      return new Response(
        `DATE,VALUE
2026-03-08,${previous}
2026-03-09,${latest}
`,
        { status: 200, headers: { "Content-Type": "text/csv" } }
      );
    }

    if (url === "https://www.federalreserve.gov/feeds/press_monetary.xml") {
      return new Response(
        `<?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <title>Federal Reserve Press Releases</title>
            <item>
              <title>FOMC statement released</title>
              <pubDate>Tue, 10 Mar 2026 10:00:00 GMT</pubDate>
              <link>https://www.federalreserve.gov/newsevents/pressreleases/monetary20260310a.htm</link>
            </item>
          </channel>
        </rss>`,
        { status: 200, headers: { "Content-Type": "application/xml" } }
      );
    }

    if (url === "https://www.bls.gov/feed/cpi.rss") {
      return new Response(
        `<?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <title>BLS CPI Releases</title>
            <item>
              <title>Consumer Price Index rose 0.2 percent in February 2026</title>
              <pubDate>Tue, 10 Mar 2026 08:30:00 GMT</pubDate>
              <link>https://www.bls.gov/news.release/cpi.nr0.htm</link>
            </item>
          </channel>
        </rss>`,
        { status: 200, headers: { "Content-Type": "application/xml" } }
      );
    }

    return new Response("Not found", { status: 404 });
  });

  assert.equal(signal.live, true);
  assert.equal(signal.headlineSummary, "Latest macro release headlines: Federal Reserve Press Releases: FOMC statement released | BLS CPI Releases: Consumer Price Index rose 0.2 percent in February 2026.");
  assert.equal(requestedUrls.length, 6);
  assert.equal(signal.sources[0]?.note, "Loaded from FRED public CSV.");
});

test("etf flow feed can aggregate fund rows and derive coverage", async () => {
  const now = new Date("2026-03-10T12:00:00Z");
  const config = readConfig({
    PORT: "0",
    MEMPOOL_BASE_URL: "https://mempool.space",
    ETF_FLOW_PROXY_URL: "https://feeds.example.com/etf"
  });

  const signal = await loadFlowSignal("auto", config, now, async () => {
    return new Response(
      JSON.stringify({
        publishedAt: "2026-03-10T09:30:00Z",
        sourceName: "ETF Aggregate Feed",
        expectedFundCount: 10,
        funds: [
          { ticker: "IBIT", netFlowUsd: 120_000_000, previousNetFlowUsd: 92_000_000 },
          { ticker: "FBTC", netFlowUsd: 55_000_000, previousNetFlowUsd: 48_000_000 },
          { ticker: "ARKB", netFlowUsd: -15_000_000, previousNetFlowUsd: -10_000_000 },
          { ticker: "BITB", netFlowUsd: 10_000_000, previousNetFlowUsd: 6_000_000 }
        ]
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  });

  assert.equal(signal.netEtfFlowUsd, 170_000_000);
  assert.equal(signal.previousNetEtfFlowUsd, 136_000_000);
  assert.equal(signal.coverage, 0.4);
  assert.equal(signal.live, true);
  assert.equal(signal.sources[0]?.status, "live");
});

test("etf flow can load directly from Glassnode and annotate a Farside cross-check", async () => {
  const now = new Date("2026-03-10T12:00:00Z");
  const requestedUrls: string[] = [];
  const config = readConfig({
    PORT: "0",
    MEMPOOL_BASE_URL: "https://mempool.space",
    GLASSNODE_API_KEY: "glass-key",
    FARSIDE_ETF_CROSSCHECK_URL: "https://farside.co.uk/btc/"
  });

  const signal = await loadFlowSignal("auto", config, now, async (input) => {
    const url = String(input);
    requestedUrls.push(url);

    if (url.startsWith("https://api.glassnode.com/v1/metrics/institutions/us_spot_etf_flows_net")) {
      return new Response(
        JSON.stringify([
          { t: "2026-03-10T00:00:00Z", v: 170_000_000 },
          { t: "2026-03-09T00:00:00Z", v: 136_000_000 }
        ]),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    if (url === "https://farside.co.uk/btc/") {
      return new Response(
        `<!doctype html>
        <table>
          <tr>
            <th>Date</th>
            <th>IBIT</th>
            <th>Total</th>
          </tr>
          <tr>
            <td>10 Mar 2026</td>
            <td>170.0</td>
            <td>170.0</td>
          </tr>
        </table>`,
        { status: 200, headers: { "Content-Type": "text/html; charset=utf-8" } }
      );
    }

    return new Response("Not found", { status: 404 });
  });

  assert.equal(signal.netEtfFlowUsd, 170_000_000);
  assert.equal(signal.previousNetEtfFlowUsd, 136_000_000);
  assert.equal(signal.coverage, 1);
  assert.equal(signal.live, true);
  assert.equal(signal.sources[0]?.id, "glassnode-etf-flows");
  assert.equal(signal.sources[0]?.name, "Glassnode US Spot BTC ETF Flows");
  assert.equal(signal.sources[0]?.note, "Farside cross-check matched the latest daily total within $0.");
  assert.equal(requestedUrls.length, 2);
  assert.match(requestedUrls[0] ?? "", /api_key=glass-key/);
  assert.equal(requestedUrls[1], "https://farside.co.uk/btc/");
});

test("bitcoin price feed returns current quote and recent delta", async () => {
  const now = new Date("2026-03-10T12:00:00Z");
  const requestedUrls: string[] = [];
  const config = readConfig({
    PORT: "0",
    MEMPOOL_BASE_URL: "https://mempool.space"
  });

  const signal = await loadBitcoinPriceSignal("auto", config, now, async (input) => {
    const url = String(input);
    requestedUrls.push(url);

    if (url.endsWith("/api/v1/prices")) {
      return new Response(JSON.stringify({ USD: 82_540.25 }), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      });
    }

    if (url.includes("/api/v1/historical-price")) {
      return new Response(JSON.stringify({ price: 82_410 }), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      });
    }

    return new Response("Not found", { status: 404 });
  });

  assert.deepEqual(requestedUrls, [
    "https://mempool.space/api/v1/prices",
    "https://mempool.space/api/v1/historical-price?currency=USD&timestamp=1773143700"
  ]);
  assert.equal(signal.priceUsd, 82_540.25);
  assert.equal(signal.deltaUsd, 130.25);
  assert.equal(signal.live, true);
  assert.equal(signal.sources[0]?.id, "mempool-price");
});
