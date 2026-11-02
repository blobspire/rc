#!/bin/sh
# rc network hook: connect Cloudflare WARP (for example, Cloudflare Zero Trust) and wait for it.
# In a computer's rc settings:  NET="$RC_HOME/examples/network/cloudflare-warp.sh"
#
# If WARP connects but names don't resolve while Tailscale is running (Tailscale's MagicDNS can
# take over DNS), set RC_WARP_STOP_TAILSCALE=1 in the settings file to stop Tailscale first.
# `tailscale up` brings it back.

WARP=$(command -v warp-cli 2>/dev/null || echo /usr/local/bin/warp-cli)
status() { "$WARP" --json status 2>/dev/null | sed -n 's/.*"status" *: *"\([^"]*\)".*/\1/p' | head -n 1; }

if [ "${RC_WARP_STOP_TAILSCALE:-}" = 1 ] && command -v tailscale >/dev/null 2>&1; then
  tailscale down && echo "tailscale: stopped ('tailscale up' restores it)"
fi
if [ "$(status)" = Connected ]; then echo "warp: already connected"; exit 0; fi
"$WARP" --accept-tos connect >/dev/null 2>&1 || { echo "warp-cli connect failed" >&2; exit 1; }
i=0
while [ $i -lt 30 ]; do
  if [ "$(status)" = Connected ]; then echo "warp: connected"; exit 0; fi
  sleep 1; i=$((i + 1))
done
echo "WARP didn't connect within 30 seconds" >&2
exit 1
