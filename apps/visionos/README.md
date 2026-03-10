# Vision Pro package foundation

This Swift package is the reusable client layer for the Bitcoin Regime Navigator MVP.

## Modules

- `BitcoinRegimeDomain`
  - contracts mirrored from the backend
  - demo data
  - service protocol and URLSession-backed client
  - local snapshot persistence
- `BitcoinRegimeUI`
  - Daily Briefing surface
  - methodology presentation
  - Mempool Arena view primitives
  - demo shell view model

## Current limitation

The repo does not yet contain a generated `.xcodeproj` or visionOS app target because no project generator is installed in this environment. The package is ready to be attached to a real visionOS app target in Xcode.
