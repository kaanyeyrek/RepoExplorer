# RepoExplorer

A small GitHub repository explorer built as a take-home case study for a senior iOS interview.
Search repositories, inspect details and contributors, bookmark favourites — with
offline support and explicit rate-limit handling.

## How to run

1. Open `RepoExplorer.xcodeproj` in Xcode (built with Xcode 26, minimum deployment target **iOS 17.0**).
2. Select any iOS simulator and press **Run**. No further setup is required.

**Optional API token.** Unauthenticated GitHub limits are tight (see below). To raise them,
add a `GITHUB_TOKEN` environment variable to the Run scheme
(*Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables*).
The token is read from the process environment only — nothing is stored in the repo,
and the app works fully without one. I kept token support in because it costs three lines
and makes reviewing the app less painful; the unauthenticated path remains the primary,
fully-handled case.

## Architecture

**MVVM with `@Observable` (iOS 17 Observation), feature-first folders, zero third-party dependencies.**

```
Core/        Models · Networking (URLSession + async/await) · Storage (DiskCache actor, BookmarkStore)
Features/    Search · Detail · Bookmarks — each: View (+ ViewModel where logic warrants it)
App/         Entry point, tab root, navigation wiring
```

Decisions, with what I turned down:

- **`@Observable` view models, owned via `@State`.** The modern replacement for
  `ObservableObject`/`@StateObject` on an iOS 17 target; views re-render only for
  properties they actually read. Dependencies are injected through initialisers; the
  API client sits behind a `GitHubAPIServing` protocol — that seam exists for
  testability, not for speculative abstraction.
- **No networking/architecture libraries.** Two endpoints and one funnel method did not
  justify Alamofire or TCA. *Rejected:* a generic `Endpoint`/router layer — at this size
  it would be structure without benefit.
- **Persistence: JSON files for cache, `UserDefaults` for bookmarks.** *Rejected:
  SwiftData/Core Data* — the data is a disposable, re-downloadable cache with two keys;
  a schema-versioned envelope on disk is simpler to reason about and to review within the
  time box. Bookmarks are a small list, which is exactly what `UserDefaults` is for.
  Where this strains at 10× scale: per-query caching, eviction and indexed lookups would
  push me to SQLite/GRDB, and bookmarks would move out of `UserDefaults` well before the
  4 MB plist regime.
- **`DiskCache` is an actor.** File I/O and JSON coding stay off the main thread, and
  concurrent access from Search and Detail serialises without hand-rolled locks.
- **Errors are typed, and layered differently by purpose.** `APIError` separates
  `offline` and `rateLimited(resetAt:)` from generic HTTP failures because the UI treats
  them differently (fall back to cache vs. show a countdown). Cache write failures, by
  contrast, are swallowed deliberately: the cache is best-effort — a failed snapshot save
  must never turn a successful search into an error state.
- **Cancellation is normalised.** `URLSession` reports cancellation as
  `URLError(.cancelled)` rather than `CancellationError`; the client maps it back, so a
  cancelled keystroke-search never flashes an error state. After every `await`, view
  models re-check `Task.isCancelled` before writing state, so a stale response can never
  overwrite a newer query's results. Pagination additionally captures the query it was
  started for (`activeQuery`), so scrolling during a half-typed new query cannot append
  mismatched pages.

## Offline

**Model: cache-then-network, single snapshot.**

- Every successful search persists a snapshot (query + accumulated results) to disk.
  On every cold start the snapshot is restored — including the query text — and labelled
  *"Saved “query” results · X ago"*; online, the same restore transparently refreshes,
  offline the labelled snapshot is what you keep. The timestamp and the query both come
  from the cache envelope, so staleness (and which search you are looking at) is always
  visible, not implied.
- Details reachable from that list keep working: the repository itself travels with the
  navigation value, and contributors fall back to their own per-repo cache, labelled
  *"Cached · X ago"*.
- *Rejected: per-query search caching.* The brief asks for the **last** search to remain
  readable; a per-query store adds unbounded growth and eviction policy for no required
  benefit. Noted under "with more time".
- Connectivity is detected from the failure (`URLError` → `.offline`), not from a
  reachability pre-check — requests are attempted honestly and degrade on error.

## Rate limiting

**The important detail: GitHub has two independent limit pools.** Unauthenticated,
`/search/*` allows **10 requests/minute**, while core endpoints (contributors) allow
**60/hour** — GitHub tracks them separately (surfaced in its `x-ratelimit-resource`
header). The app mirrors that split structurally rather than by parsing that header:
rate-limit state lives per feature, so it never becomes a global condition: a throttled search shows its countdown
in the search screen while the detail screen stays fully usable, which also matches the
brief's requirement that the contributors call fails independently.

Behaviour I chose, and why:

- 403 **and** 429 are both handled; a response only counts as rate-limited when
  `x-ratelimit-remaining == 0` or `retry-after` is present — a plain 403 (auth error)
  must not masquerade as "please wait".
- The reset moment is parsed from `retry-after` (relative seconds) or
  `x-ratelimit-reset` (epoch seconds) into a `Date`, and surfaced as a **live countdown**
  with a retry button that only activates when the window reopens. No automatic retry
  loops: GitHub's own guidance warns that hammering while limited risks a ban, and a
  countdown communicates more honestly than a spinner.
- Existing results are never discarded on a rate limit — the banner overlays content
  instead of replacing it. Pagination hits show the same treatment inline at the list's
  end.

**To see it live:** type ~11 distinct queries within a minute (unauthenticated) and watch
the banner count down. I verified this path by triggering it, not just by reading the headers.

## Tests

`Cmd+U` — or `xcodebuild test -scheme RepoExplorer` — runs **20 Swift Testing cases** in
four suites, deliberately focused on the decision-heavy logic rather than breadth:

- **API client** (stubbed with `URLProtocol`) — rate-limit detection (403 with
  `x-ratelimit-remaining: 0` becomes a typed error with a parsed reset date, while a
  plain 403 stays an HTTP error), `retry-after` parsing, the contributors `204 → []`
  path, offline mapping, and null-tolerant decoding.
- **Search view model** (protocol stub) — cross-page dedupe by ID, the 1 000-result
  ceiling stopping pagination, blank queries never reaching the API, the rate-limit /
  offline-fallback state transitions, and two race regressions: returning from a detail
  push must not refetch (and burn rate limit), and a stale in-flight pagination response
  must be dropped instead of polluting a newer query's results.
- **Detail view model** — contributors success/empty, and rate-limit with and without a
  cache to fall back on.
- **Disk cache** — round-trip, corrupted-file self-healing, schema-version invalidation.

## With more time I would

- **Broaden test coverage** — UI tests for the offline and rate-limit flows; today's
  20 unit tests target the decision-heavy core, including the cancellation races.
- **Disk-cache avatars.** `AsyncImage` has no persistent store, so images degrade to
  placeholders offline; a small disk-backed image loader would fix that.
- **Conditional requests (ETag / If-None-Match).** I looked into it and *chose not to*:
  304s still count against the unauthenticated rate limit, so it buys nothing for the
  primary path — it becomes worthwhile only with a token.
- Per-query search cache with eviction; localisation; richer detail (README preview,
  languages breakdown); UI polish passes.

## Honest notes

- The weakest remaining edge is the offline image experience (see "with more time").
  The search cache is a single last-query snapshot by design — switching between older
  queries offline only restores the most recent one, and the banner now names the query
  it is showing so that mismatch is visible rather than silent.
- Bookmarks persist the repository payload inside the same schema-versioned envelope the
  disk cache uses; a breaking model change invalidates rather than migrates them — a
  dedicated bookmark model with migration is a "with more time" item.
- Search results deduplicate by repository ID across pages (GitHub's ordering can shift
  between pages), and `canLoadMore` respects GitHub's hard 1 000-result search ceiling to
  avoid guaranteed 422s during infinite scroll.
