# visionOS app wrapper

This folder contains the runnable visionOS app target that wraps the package-based MVP foundation.

## Runtime mode

- The shared run scheme sets `BITCOIN_REGIME_API_BASE_URL=http://127.0.0.1:8787`, so the app loads live data from the local backend by default.
- Override `BITCOIN_REGIME_API_BASE_URL` in the run scheme if the backend is hosted elsewhere.
