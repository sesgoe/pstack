# Execute and Probe

Each reviewer applies this lens in addition to the rubric and the code-quality lens. It turns
the review from reading code into running it. Adapted from Tim Vykruta's REVIEW.md
(https://x.com/tvykruta/status/2106138761511727451), keeping only what the rubric and
code-quality lens do not already cover.

## Execute, Don't Read

- Before you read the implementation, write down the inputs you will test. Inputs written after reading the code take the code's shape and miss what it misses.
- Run the changed code on those inputs in your own worktree. Where possible, probe read-only against a copy of real data.
- Compare results against the base commit every time, including when the head is green.
- Green tests are not evidence. Say what you executed. If you could not execute something, say so and why; a finding from reading alone is weaker and must be labeled that way.

## What to Probe

- Every alternative form of an input, including forms that combine two of them.
- Every unit, and the input with no unit at all.
- Two or more entities in one input, in every order.
- Every consumer of a changed enum, status, or constant.
- Every reason or error code, traced to the message the user actually sees.
- Every place the same fact is stored, computed, or rendered (server and client). Do they still agree?
- Boundaries: empty, one, exactly at the threshold, past the top.
- Dates: leap days, year boundaries, time zones.

## Honesty of Data

- Unknown stays unknown. The UI never invents, guesses, or silently resolves data it does not have.
- Every label must be true for every record it is shown on.

## Design Principles: Report on Every One

For each, state OK or a violation with file:line. A principle left unmentioned is an incomplete review.

- Separation of concerns
- Programming by intention
- Encapsulation
- High cohesion
- Low coupling

Always blocking: a domain with two owners, duplicated logic, business logic in templates or UI code.

## Gates and Tooling

When the change adds or edits a check, hook, gate, or rule:

- Attack it with inputs it should reject, including ones phrased differently to evade it.
- Prefer platform primitives (for example git pre-push) over clever parsing of commands.
- Confirm every exemption still points at something that exists, and that no exemption can be used to sneak code through.
- Installing a hook must not disable hooks already in place.
- Edits to the rules themselves are never exempt from review.

## Docs and Moves

- After any search-and-replace or move, re-read every edited sentence and ask: is this still true?
- Dated docs keep their old paths and facts.
