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

# gh, then pr, then create or new, as words; -R/--repo options may sit in between.
w='[^[:alnum:]_-]'
args='([^"]*[[:space:]])?'
pr_create="(^|$w)gh[[:space:]]${args}pr[[:space:]]${args}(create|new)($w|\$)"

if [ "$hook" = "pre-pr-check" ] && grep -Eq "$pr_create"; then
  echo "Thoth needs Node.js 18 or later to run its pre-PR checks, and node isn't on the PATH." >&2
  echo "Ask the user to install Node (https://nodejs.org), then retry." >&2
  exit 2
fi

exit 0
