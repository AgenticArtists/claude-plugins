# Meta-prompt: write the next loop's brief

Run this at the end of every finished loop, before the session's context is
lost. It is the step that gives the loop system a memory.

---

**1. Capture what only you know.** Review the commits this loop produced and the
subagent reports. Write down specifically:

- What shipped (one line each), so the next planner doesn't re-plan it
- What was explicitly deferred, descoped, or flagged "worth a dedicated pass"
  by the planner, worker, or reviewer — the strongest candidates for later
- What anyone could not verify and had to assume: missing credentials,
  unreachable services, no live data, network restrictions
- Any reviewer finding accepted as non-blocking rather than fixed
- Any deviation from the plan, and why

Quote the subagent reports. `git log` preserves none of this, and it is gone the
moment the session ends. This is the main value of the exercise.

**2. Update the backlog before choosing anything.** Add what part 1 surfaced to
the backlog file named in `.claude/loop.config.json`, and strike what this loop
actually fixed. Do this *first*, so the theme is chosen against the full list
rather than against whatever happens to be in your context window.

**3. Pick one theme for the next loop and justify it.** Not a grab bag.

Choose from the **whole backlog**, not just this loop's leftovers. You have just
spent an entire session inside one problem area, and the strongest candidate
will feel like more of it. That feeling is availability bias, not evidence. An
item that has sat untouched for three loops is usually the better answer than a
fourth pass on today's topic.

Prefer, in order: (a) work that makes future loops safer or faster — tests,
tooling, CI — because it compounds; (b) items explicitly deferred by *any*
previous loop, oldest first; (c) a depth pass on an area only touched shallowly.

**Name the two themes you rejected and why** — one must be "continue the current
theme," with a real reason it loses. If you can't argue against continuing,
that's a signal you haven't read the backlog properly.

If the honest answer is that the highest-value next step needs a human —
provision a database, grant access, make a product decision — **say that instead
of inventing agent work to fill the slot.** Check whether a "needs a human" item
is now blocking everything else.

**4. Rotate the brief.** The kickoff prompt must never change, so the current
brief always lives at the same path (`paths.brief` in the config):

```
git mv <paths.brief> <paths.archive>/<YYYY-MM-DD>-<finished-theme>.md
# then write the new brief to <paths.brief>
```

The brief must work for a **cold session with no memory of this one**. Include:

- The "what just landed, don't re-plan it" list from part 1
- The mission, ordered by risk and leverage rather than by category — the paths
  where a silent regression is worst go first
- What's already true, so the next loop doesn't rebuild it. Audit the area
  first: "these six things are actually broken, here's the evidence" is worth
  far more than "consider looking at performance"
- Environment constraints that will actually bite: what a fresh clone lacks,
  services that fail closed, tools that must not be reinstalled
- A **falsifiable** definition of done. "Tests exist" is not. "Each test fails
  when its protection is removed, verified by temporarily removing it" is. And
  if it makes a claim about a clean environment, require that it be checked in
  one — a definition of done has been signed off before while being false.

Commit and push the archive move and the new brief together.

**5. Report.** Tell the user: the theme you chose and why, what you rejected,
and anything they must provide before the next loop can run — being explicit
about whether the loop is *blocked* without it or merely better with it. Confirm
the next loop starts with the same unchanged prompt: `/ship`.
