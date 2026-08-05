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

**Only if a brief will touch a sibling repo** (a companion pipeline, a shared
library checked out next to this one) — omit otherwise:

```json
{
  "siblingRepos": [
    { "path": "../research", "mainBranch": "main" }
  ]
}
```

`/ship`'s landing step pushes each configured sibling too, when it has unpushed
commits, so a loop never leaves cross-repo work stranded on one side. Only add a
sibling that's actually a git repo at that relative path; a cloud session can't
see anything outside its own checkout, so this only fires anything on a local
session where the path exists — `/ship` skips it with a note otherwise, not an
error.

## 3. Vendor the plugin into the repo, so fresh sessions load it automatically

**Copy the plugin into this repo and register it from a local directory. Do not
use a `github` marketplace source.** Claude Code cloud containers do not fetch
remote marketplaces at session start, so a `github` source silently yields a
repo where `/ship` comes back "Unknown command" and there is nothing to debug
from inside the session.

Copy these two paths from `AgenticArtists/claude-plugins` — the canonical
master — into this repo's root, preserving file modes:

```
.claude-plugin/marketplace.json
plugins/agentic-loop/            (the whole tree)
```

`plugins/agentic-loop/hooks/loop-guard.sh` **must** be committed mode `100755`.
Without the executable bit the `Stop` hook silently does nothing, and loops are
free to end half-finished. Verify after committing:

```
git ls-files -s plugins/agentic-loop/hooks/loop-guard.sh   # expect 100755
```

### Then make the commands load without a plugin

**A marketplace registration is not enough, and on its own it does nothing in a
cloud container.** Registering the plugin in `.claude/settings.json` — `github`
source *or* vendored `directory` source — leaves `/ship` returning "Unknown
command" there, with `~/.claude/plugins` never created and nothing logged. Wire
it up as project files instead, which are read straight from the working tree:

Copy the command files into `.claude/commands/`, rewriting the template
references, since `${CLAUDE_PLUGIN_ROOT}` is only set for a loaded plugin:

```
sed 's|${CLAUDE_PLUGIN_ROOT}/templates|plugins/agentic-loop/templates|g' \
  plugins/agentic-loop/commands/ship.md > .claude/commands/ship.md
```

Declare the `Stop` hook directly in the repo's committed `.claude/settings.json`
too — the plugin's `hooks/hooks.json` is only read when the plugin loads (merge,
never replace existing keys):

```json
{
  "hooks": {
    "Stop": [{ "hooks": [{
      "type": "command",
      "command": "\"$CLAUDE_PROJECT_DIR/plugins/agentic-loop/hooks/loop-guard.sh\"",
      "timeout": 10
    }]}]
  }
}
```

Verify the hook both ways before moving on — with no `.claude/.loop-active` it
must exit 0 silently, and with one it must emit `"decision": "block"`:

```
bash plugins/agentic-loop/hooks/loop-guard.sh </dev/null; echo "exit=$?"
```

You may also add `extraKnownMarketplaces` + `enabledPlugins` with a directory
source. That's harmless and makes the plugin path work from a desktop CLI, but
it is not what makes `/ship` resolve in a cloud session — don't let its presence
convince you the repo is set up.

The tradeoff is that a copy is a copy: when the plugin changes upstream, someone
has to re-copy it into every consuming repo, `.claude/commands/` included. See
the claude-plugins README.

## 4. Allowlist the gate commands, so loops don't spam permission prompts

Add a `permissions.allow` block to the same `.claude/settings.json` (merge —
never replace existing `allow`/`ask`/`deny` entries or other keys). Without
this, every command a loop runs — including every command in `gate` — prompts
for approval on its first use, which defeats an unattended loop. Cover:

- Every command in the `gate` array you wrote in step 2, plus its natural
  neighbors (e.g. if `gate` runs `npm test`, also allow `npm run <script>`
  generally rather than one exact invocation, so a slightly different flag
  doesn't re-prompt).
- Ordinary read-only git inspection and the git commands a loop needs to ship:
  `git diff`, `git status`, `git log`, `git fetch`, `git add`, `git commit`,
  `git push`.
- Ordinary read-only shell inspection: `ls`, `cat`, `find`, `grep`.

```json
{
  "permissions": {
    "allow": [
      "Bash(git diff*)",
      "Bash(git status*)",
      "Bash(git log*)",
      "Bash(git fetch*)",
      "Bash(git add*)",
      "Bash(git commit*)",
      "Bash(git push*)",
      "Bash(ls*)",
      "Bash(cat*)",
      "Bash(find*)",
      "Bash(grep*)",
      "Bash(<each gate command from step 2>*)"
    ]
  }
}
```

Do not allowlist anything destructive or that reads secrets while you're at
it — `git push --force`/`-f`, `git reset --hard`, and `.env*` files should stay
un-allowlisted (add them to `deny` if the repo doesn't already exclude them).

## 5. Seed the files

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

## 6. Tell the repo's own instructions about the loop

If the repo has a `CLAUDE.md`, add a short section: the loop runs via `/ship`,
the brief always lives at `paths.brief`, a loop isn't finished until it has
landed on `mainBranch` **and** written the next brief, and `.claude/.loop-active`
marks those as outstanding. Without this, a session that didn't invoke `/ship`
has no idea the convention exists.

## 7. Report

Show the config you wrote and the evidence behind each value, the backlog items
you seeded, the first brief's theme and why, and confirm the gate passes today.
Then tell the user they can start with `/ship`.
