#!/usr/bin/env bash
# Stop hook: refuse to end a session that started an agentic loop but never
# finished it.
#
# "Finished" means two things sessions reliably skip:
#   1. the work is merged and pushed to the release branch, not left on a
#      feature branch nobody merges
#   2. the backlog is updated and the next loop's brief is written
#
# The gate is a marker file that /loop creates on kickoff and deletes only
# after both are done. No marker => this hook does nothing at all, so ordinary
# sessions in a repo with this plugin installed are completely unaffected.
#
# Repo-agnostic: reads .claude/loop.config.json when present for the branch and
# gate commands, and degrades to generic wording when it is absent or jq is not
# installed. It must never be the reason a session cannot end.

set -uo pipefail

input=$(cat 2>/dev/null || echo '{}')

have_jq() { command -v jq >/dev/null 2>&1; }

# stop_hook_active is true when this hook already blocked once and the model is
# now doing the follow-up work. Blocking again would spin forever.
if have_jq && [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ]; then
  exit 0
fi

root="${CLAUDE_PROJECT_DIR:-$PWD}"
marker="$root/.claude/.loop-active"
config="$root/.claude/loop.config.json"

[ -f "$marker" ] || exit 0

brief=$(head -n1 "$marker" 2>/dev/null || true)
[ -n "$brief" ] || brief="the current brief"

branch="main"
gate="your repo's verification commands (lint / build / test)"
if [ -f "$config" ] && have_jq; then
  cfg_branch=$(jq -r '.mainBranch // empty' "$config" 2>/dev/null || true)
  [ -n "$cfg_branch" ] && branch="$cfg_branch"
  cfg_gate=$(jq -r '(.gate // []) | join(", ")' "$config" 2>/dev/null || true)
  [ -n "$cfg_gate" ] && gate="$cfg_gate"
fi

reason="The agentic loop started from ${brief} is not finished. \
.claude/.loop-active still exists, which means at least one of the two closing \
steps has not happened yet. Do them now, in order:

1. LAND IT ON ${branch}. Check \`git branch --show-current\` and \
\`git log origin/${branch}..HEAD\`. If the work is sitting on a feature branch, \
merge it into ${branch}, re-run the gate (${gate}) ON THE MERGED RESULT, then \
push. A loop that ends with approved work stranded on a branch has shipped nothing.

2. UPDATE THE BACKLOG AND WRITE THE NEXT BRIEF. Follow the write-next-loop-brief \
instructions referenced by your repo's loop config: update the backlog first, \
then choose a theme against the whole backlog naming the alternatives you \
rejected, then archive the finished brief and write the new one back to the \
SAME stable path so the kickoff prompt never changes. This captures what only \
this session knows and is lost forever when the session ends.

3. Then delete the marker: rm .claude/.loop-active

If the loop was genuinely abandoned rather than completed, deleting the marker \
alone is fine -- but say so explicitly rather than silently."

if have_jq; then
  jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
else
  # Without jq, fall back to exit code 2: stderr is fed back to the model.
  printf '%s\n' "$reason" >&2
  exit 2
fi
