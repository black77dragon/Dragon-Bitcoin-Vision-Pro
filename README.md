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

## Validate

```bash
cd /Users/renekeller/Dragon-Bitcoin-Vision-Pro/apps/api
npm test

cd /Users/renekeller/Dragon-Bitcoin-Vision-Pro/apps/visionos
swift test
```

## Source concept

The original concept files are stored in `docs/concept/` so the repo remains the canonical project record.
