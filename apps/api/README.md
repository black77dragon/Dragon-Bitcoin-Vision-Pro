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

- `FRED_API_KEY` enables live macro inputs from the FRED API.
- `ETF_FLOW_PROXY_URL` may point to an internal JSON feed shaped like:

```json
{
  "publishedAt": "2026-03-10T12:00:00Z",
  "netInflowUsd": 185000000,
  "coverage": 0.8,
  "sourceName": "ETF Proxy Feed"
}
```
