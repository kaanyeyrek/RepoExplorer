# AI Usage

## Tools

**Claude (Anthropic)** — used as a pair programmer throughout, via the Claude Code CLI.
No other AI tools were used.

## How it was used

My daily workflow at my previous role was already agentic (Claude Code with MCP
integrations for Xcode, App Store Connect and Crashlytics), and I worked on this case the
same way I work on production code: **I own the architecture and every decision; the AI
drafts, I direct, review and correct.**

Concretely:

- **Research before code.** Before writing the client I had Claude run a research pass to
  verify current facts against primary sources: GitHub's split rate-limit pools
  (search 10/min unauthenticated vs core 60/hour — which shaped the per-resource
  rate-limit design), 403-vs-429 semantics and header names, the 1 000-result search
  ceiling, the contributors 204 behaviour, and current `@Observable`/`.task(id:)` idioms
  on an iOS 17 target. Several design choices in the README trace directly to that pass.
- **Layer-by-layer generation with review.** Each layer (models → networking → storage →
  view models → views) was drafted by the AI to my spec, then reviewed by me before
  committing. Every build was verified on the simulator; the offline and rate-limit paths
  were exercised for real (airplane-mode walkthrough, 11-searches-in-a-minute trigger),
  not assumed from code.

## What I rejected or reworked

- **A real Swift pattern-matching bug in AI output.** The first draft of the response
  validator used `case 403, 429 where isRateLimited(response):` — in Swift the `where`
  clause binds only to the *last* pattern, so a plain 403 auth failure would have been
  misclassified as rate-limited. Caught in review, restructured into an explicit
  `if` inside `case 403, 429:`.
- **Cache-key collisions.** The first `DiskCache` draft sanitised file names by replacing
  `/` and spaces, which is not injective (`"a/b_c"` vs `"a_b/c"` collide). Reworked to
  percent-encoding, which guarantees uniqueness.
- **ETag support** suggested during research was evaluated and deliberately dropped:
  conditional 304s still count against the unauthenticated rate limit, so it added
  complexity without helping the primary path (documented in the README).

## Ownership

I can walk through and defend every line in this repository without assistance, and I'm
happy to do the live-change portion of the conversation with AI off — that mirrors how I
review my own team's AI-assisted output anyway.
