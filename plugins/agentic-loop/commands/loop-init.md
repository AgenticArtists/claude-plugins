---
description: Set up this repo for the agentic loop (config, brief, backlog, gitignore)
argument-hint: "[optional: what the first loop should focus on]"
---

Set this repository up to run `/ship`. Do the investigation yourself — every
value below must come from reading the repo, not from a default.

## 1. Work out how this repo verifies and ships

Read what's actually there: `package.json` scripts, `Makefile`, `Cargo.toml`,
`pyproject.toml`, `go.mod`, CI workflows under `.github/workflows/`, and any
`CONTRIBUTING.md` or `CLAUDE.md`. Determine:

- **`mainBranch`** — the branch that releases. Check `git symbolic-ref
  refs/remotes/origin/HEAD` rather than assuming `main`.
- **`gate`** — the ordered commands that must pass before shipping. Prefer what
  CI runs, since that's the definition the project already trusts. Order
  matters: if a test suite reads build output, the build goes first.
- **`deploy`** — `{"mode": "push"}` when merging to `mainBranch` triggers a
  deploy (Vercel, Netlify, a CI pipeline); `{"mode": "command", "command":
  "..."}` when a command deploys; `{"mode": "none"}` for a library or anything
  not continuously deployed.

**Verify the gate actually passes right now**, before writing it down. If the
repo is already red, say so — the first loop must not inherit a broken baseline
and be blamed for it.

## 2. Write `.claude/loop.config.json`

```json
{
  "mainBranch": "main",
  "gate": ["npm run lint", "npm run build", "npm test"],
  "deploy": { "mode": "push", "note": "Vercel auto-deploys from main" },
  "paths": {
    "brief": ".claude/prompts/next-loop.md",
    "backlog": ".claude/prompts/backlog.md",
    "archive": ".claude/prompts/archive"
  }
}
```

## 3. Register the plugin in the repo, so fresh sessions load it automatically

Add this to the repo's committed `.claude/settings.json` (merge — never replace
existing keys):

```json
{
  "extraKnownMarketplaces": {
    "agenticartists": {
      "source": { "source": "github", "repo": "agenticartists/bestokc.com" }
    }
  },
  "enabledPlugins": { "agentic-loop@agenticartists": true }
}
```

This matters more than it looks. A `/plugin install` writes to the *machine's*
home directory, so in an ephemeral cloud container it evaporates when the
session ends and every future session would have to reinstall by hand.
Committing the registration to the repo makes `/ship` available in any fresh
session with no setup at all.

## 4. Seed the files

- Create `paths.archive`.
- Copy `${CLAUDE_PLUGIN_ROOT}/templates/backlog.md` to `paths.backlog`, then
  **seed it with real findings** — spend a little time auditing: missing CI, no
  lockfile, untriaged advisories, dead test suites, stale TODOs, anything
  already known-broken. An empty backlog gives the first loop nothing to reason
  against and the whole cross-loop memory starts hollow. Mark each item verified
  or suspected, and never record a guess as a fact.
- Write the first brief to `paths.brief`, based on
  `${CLAUDE_PLUGIN_ROOT}/templates/first-loop.md`. If the user gave `$1`, that's
  the theme; otherwise choose the highest-leverage starting point from what you
  found — work that makes later loops safer (tests, CI, tooling) usually beats
  features, because it compounds.
- Add `.claude/.loop-active` to `.gitignore`.

## 5. Tell the repo's own instructions about the loop

If the repo has a `CLAUDE.md`, add a short section: the loop runs via `/ship`,
the brief always lives at `paths.brief`, a loop isn't finished until it has
landed on `mainBranch` **and** written the next brief, and `.claude/.loop-active`
marks those as outstanding. Without this, a session that didn't invoke `/ship`
has no idea the convention exists.

## 6. Report

Show the config you wrote and the evidence behind each value, the backlog items
you seeded, the first brief's theme and why, and confirm the gate passes today.
Then tell the user they can start with `/ship`.
