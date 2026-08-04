# Next loop: <theme>

**How to start this loop:** in a fresh session on the release branch, type
`/loop`. That is the whole prompt, and it stays the same for every loop. It
reads this file, which is always the current brief.

---

## Why this loop exists

<One paragraph: what problem this loop solves and why it beats the alternatives
right now. If this is the first loop, say what state the repo is in and what
makes this the right starting point.>

## What just landed — do not re-plan these

<One line per item shipped by the previous loop. On a first loop, replace with a
short summary of what already exists and works, so the planner doesn't rebuild
it. Be specific: "sitemap, robots, canonicals and JSON-LD are already present on
every route" saves an entire wasted loop.>

## The mission

Ordered by risk and leverage — where a silent regression is worst goes first,
not by category.

### Priority 1 — <the thing that justifies the loop>

<Concrete, verified items. Say what's broken, where, and what evidence you have.
Mark anything unconfirmed as suspected and make confirming it the first task.>

### Priority 2 — <next>

### Priority 3 — <next>

## Constraints the planner must know

<What a fresh clone lacks. Services that fail closed. Tools that must not be
reinstalled. Credentials that won't be present and what degrades without them.
Anything that will otherwise be discovered the hard way, mid-loop.>

## Definition of done

<Falsifiable statements only. Not "tests exist" but "each test fails when its
protection is removed, verified by removing it." If a claim concerns a clean
environment, require it be checked in one.>

- The full gate (see `.claude/loop.config.json`) passes on the merged result.
- <theme-specific, checkable outcomes>
