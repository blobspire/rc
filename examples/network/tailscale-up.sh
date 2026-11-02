#!/bin/sh
# rc network hook: start Tailscale if it isn't running.
# In a computer's rc settings:  NET="$RC_HOME/examples/network/tailscale-up.sh"
#
# A bare `tailscale up` refuses to run if you've changed any Tailscale settings, and prints the
# full command that restates them instead. This runs that suggested command, so your settings
# are kept.

TS=$(command -v tailscale 2>/dev/null || echo /Applications/Tailscale.app/Contents/MacOS/Tailscale)
state() { "$TS" status --json 2>/dev/null | sed -n 's/.*"BackendState": *"\([^"]*\)".*/\1/p' | head -n 1; }

if [ "$(state)" = Running ]; then echo "tailscale: already running"; exit 0; fi
echo "tailscale: $(state) -> starting"
if out=$("$TS" up --timeout=30s 2>&1); then echo "tailscale: running"; exit 0; fi

suggested=$(printf '%s\n' "$out" | sed -n 's/^[[:space:]]*tailscale up \(.*\)$/\1/p' | head -n 1)
if [ -z "$suggested" ]; then
  printf '%s\n' "$out" >&2
  case $out in
    *"ccess denied"*|*"ermission"*) echo "On Linux, let your user run Tailscale once with: sudo tailscale set --operator=\$USER" >&2 ;;
  esac
  exit 1
fi
# shellcheck disable=SC2086  # the suggestion is a list of flags
"$TS" up $suggested || exit 1
echo "tailscale: running"
