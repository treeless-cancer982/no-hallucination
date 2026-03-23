# Last Session — 2026-03-23 14:30 CET

## What happened
- Added rate limiting middleware to API endpoints
- Fixed pagination bug in /users endpoint (off-by-one on last page)
- Updated dependencies: express 4.21.1 → 4.21.2

## Decisions
- Rate limiter uses sliding window (not fixed window) — better UX for bursty traffic

## Unresolved
- Integration tests for rate limiter not written yet
- docs/api.md needs rate limit headers documented
