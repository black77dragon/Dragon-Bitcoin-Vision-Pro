# visionOS app wrapper

This folder contains the runnable visionOS app target that wraps the package-based MVP foundation.

## Runtime mode

- If `BITCOIN_REGIME_API_BASE_URL` is set in the run scheme, the app loads live data from the backend.
- If it is not set, the app falls back to the deterministic demo service.
