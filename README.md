# Bitcoin Regime Navigator

Internal prototype repository for the Apple Vision Pro-first Bitcoin Regime Navigator MVP.

## What is in this repo

- `docs/` contains the source concept files and the implementation master plan.
- `packages/contracts/` locks the initial public API in OpenAPI form.
- `apps/api/` contains a dependency-light TypeScript API that can run directly on Node 24.
- `apps/visionos/` contains the Swift package foundation for the Vision Pro briefing and arena UI.

## Current MVP baseline

- Daily Briefing contract and mock/live data assembly
- Mempool replay generation and methodology endpoint
- Swift domain models, demo data, and reusable Vision Pro UI components

## Run the backend

```bash
cd /Users/renekeller/Dragon-Bitcoin-Vision-Pro/apps/api
npm run dev
```

The backend uses Node 24's `--experimental-transform-types` support, so it does not require a TypeScript toolchain for local execution.
For production-style feeds, configure `MACRO_SIGNAL_URL`, `MACRO_NEWS_FEED_URLS`, `GLASSNODE_API_KEY`, and/or `ETF_FLOW_PROXY_URL` in the API environment. Macro metrics can come from the FRED JSON API when `FRED_API_KEY` is set or from FRED's public CSV downloads when it is not.

The current large-buyer stack is:

- Glassnode as the primary U.S. spot ETF flow source
- Farside as a daily cross-check note when enabled
- `ETF_FLOW_PROXY_URL` as an explicit override when you want to supply your own aggregate feed

For a live macro-news layer without a paid vendor, set:

```bash
MACRO_NEWS_FEED_URLS=official
```

That expands to official public RSS feeds from the Federal Reserve and BLS:

- `https://www.federalreserve.gov/feeds/press_monetary.xml`
- `https://www.bls.gov/feed/empsit.rss`
- `https://www.bls.gov/feed/cpi.rss`
- `https://www.bls.gov/feed/ppi.rss`

## Validate

```bash
cd /Users/renekeller/Dragon-Bitcoin-Vision-Pro/apps/api
npm test

cd /Users/renekeller/Dragon-Bitcoin-Vision-Pro/apps/visionos
swift test
```

## Source concept

The original concept files are stored in `docs/concept/` so the repo remains the canonical project record.
