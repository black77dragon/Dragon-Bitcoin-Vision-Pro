# API scaffold

This service is intentionally dependency-light so the prototype can run without installing a framework stack.

## Endpoints

- `GET /healthz`
- `GET /v1/briefing/current?mode=auto|demo|live`
- `GET /v1/mempool/replay?range=6h|24h&bucket=1m|5m&mode=auto|demo|live`
- `GET /v1/methodology`

## Data modes

- `auto`: use live mempool data when available and fall back to demo data for missing providers
- `demo`: deterministic offline mode for design reviews and investor demos
- `live`: require live providers where implemented, then degrade source confidence if fallbacks are needed

## External configuration

- `REPLAY_STORE_PATH` controls where rolling replay frames are stored locally. Default: `./data/replay-frames.json`
- `MACRO_SIGNAL_URL` may point to a production JSON feed shaped like:

```json
{
  "publishedAt": "2026-03-10T12:00:00Z",
  "sourceName": "Macro Composite Feed",
  "coverage": 0.95,
  "news": [
    {
      "title": "Fed releases March policy statement",
      "publishedAt": "2026-03-10T10:30:00Z",
      "sourceName": "Federal Reserve"
    }
  ],
  "metrics": {
    "dollarIndex": { "latest": 122.4, "previous": 123.1 },
    "realYield10y": { "latest": 1.61, "previous": 1.66, "unit": "%" },
    "liquidityProxy": { "latest": 7248, "previous": 7220, "unit": "bn", "cadence": "weekly" },
    "riskProxy": { "latest": 5275, "previous": 5228 }
  }
}
```

- `MACRO_NEWS_FEED_URLS` may be a comma-separated list of RSS/Atom feeds used to enrich the macro card with recent release headlines. Use `official` to enable the built-in public feed set:
  - `https://www.federalreserve.gov/feeds/press_monetary.xml`
  - `https://www.bls.gov/feed/empsit.rss`
  - `https://www.bls.gov/feed/cpi.rss`
  - `https://www.bls.gov/feed/ppi.rss`

## Replay behavior

- non-demo replay requests append the current network snapshot into the local replay store
- replay responses prefer saved frames and backfill older gaps with deterministic history until enough live frames accumulate

- `FRED_API_KEY` enables the JSON FRED API. If it is not set, the backend falls back to FRED's public CSV series downloads for the same macro inputs.
- `GLASSNODE_API_KEY` enables direct U.S. spot ETF net-flow ingestion from Glassnode.
- `GLASSNODE_BASE_URL` defaults to `https://api.glassnode.com/`.
- `FARSIDE_ETF_CROSSCHECK_URL` defaults to `https://farside.co.uk/btc/`. Set it to `off` to disable the cross-check note.
- `ETF_FLOW_PROXY_URL` may point to an internal JSON feed shaped like:

```json
{
  "publishedAt": "2026-03-10T12:00:00Z",
  "sourceName": "ETF Aggregate Feed",
  "expectedFundCount": 10,
  "funds": [
    { "ticker": "IBIT", "netFlowUsd": 120000000, "previousNetFlowUsd": 92000000 },
    { "ticker": "FBTC", "netFlowUsd": 55000000, "previousNetFlowUsd": 48000000 }
  ]
}
```

## Flow source order

`loadFlowSignal()` resolves sources in this order:

1. `ETF_FLOW_PROXY_URL` if you provide an internal aggregate feed
2. Glassnode direct fetch when `GLASSNODE_API_KEY` is present
3. deterministic demo fallback

When the Glassnode path is used, the API also attempts a best-effort Farside validation pass and stores the result in the source `note`.
