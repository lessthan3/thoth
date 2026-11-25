#!/bin/sh
# Runs a Thoth hook script with Node. Without Node on the PATH, the hook would fail with
# "node: command not found", which blocks every gh command through the gate's onFailure. Instead:
# session start tells the user to install Node, skill activation is skipped, and the gate blocks
# only PR creation, saying what to install.
hook="$1"

if command -v node >/dev/null 2>&1; then
  # session-start only exists to report a missing Node.
  [ "$hook" = "session-start" ] && exit 0
  exec node "${CLAUDE_PLUGIN_ROOT}/dist/${hook}.mjs"
fi

if [ "$hook" = "session-start" ]; then
  echo '{"systemMessage": "Thoth needs Node.js 18 or later, and node is not on the PATH.' \
    'Skill suggestions are off and gh pr create is blocked until you install it:' \
    'https://nodejs.org"}'
  exit 0
fi

[ "$hook" = "pre-pr-check" ] || exit 0

# The Bash command from the hook's JSON input (tool_input.command), still JSON-escaped. Matching
# only this field keeps a tool description that mentions gh pr create from triggering the block.
command=$(tr '\n' ' ' | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p')

# The Node gate's pattern: gh, pr, then create or new, with only -R/--repo options in between.
w='[^[:alnum:]_-]'
repo_opt='([[:space:]]+(-R|--repo)(=|[[:space:]]+)[^[:space:]]+)*'
pr_create="(^|$w)gh${repo_opt}[[:space:]]+pr${repo_opt}[[:space:]]+(create|new)($w|\$)"

if printf '%s\n' "$command" | grep -Eq "$pr_create"; then
  echo "Thoth needs Node.js 18 or later to run its pre-PR checks, and node isn't on the PATH." >&2
  echo "Ask the user to install Node (https://nodejs.org), then retry." >&2
  exit 2
fi
