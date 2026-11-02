#!/usr/bin/env bash
# Install rc: link the `rc` command onto your PATH and rc's skill (other-computers) into Claude Code.
# Safe to re-run, for example after `git pull`. `./install.sh --uninstall` removes both links.
set -euo pipefail

REPO=$(cd -P "$(dirname "$0")" && pwd)
BIN=${RC_BIN_DIR:-$HOME/.local/bin}
SKILLS=${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}
CONF=${RC_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/rc}

SKILL=other-computers
ours() { [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]; }

if [ "${1:-}" = --uninstall ]; then
  ours "$BIN/rc" "$REPO/rc" && rm "$BIN/rc" && echo "removed $BIN/rc"
  ours "$SKILLS/$SKILL" "$REPO/skills/$SKILL" && rm "$SKILLS/$SKILL" && echo "removed $SKILLS/$SKILL"
  echo "Your settings in $CONF were left in place."
  exit 0
fi

link() { # link <source> <destination> <description>
  if ours "$2" "$1"; then echo "ok       $3: $2"; return 0; fi
  if [ -e "$2" ] || [ -L "$2" ]; then
    echo "SKIPPED  $3: $2 already exists and isn't rc's. Move it aside and run this again."
    return 1
  fi
  ln -s "$1" "$2"
  echo "linked   $3: $2 -> $1"
}

mkdir -p "$BIN" "$SKILLS" "$CONF/computers"
chmod +x "$REPO/rc" "$REPO"/examples/network/*.sh
status=0
link "$REPO/rc" "$BIN/rc" "command" || status=1
link "$REPO/skills/$SKILL" "$SKILLS/$SKILL" "Claude Code skill" || status=1

hash -r 2>/dev/null || true
found=$(command -v rc || true)
case ":$PATH:" in
  *":$BIN:"*)
    if [ -n "$found" ] && [ "$found" != "$BIN/rc" ]; then
      echo "WARNING  '$found' comes before $BIN on your PATH, so 'rc' runs that instead."
      echo "         Move $BIN earlier in PATH in your shell profile."
    fi ;;
  *)
    echo "NOTE     $BIN isn't on your PATH. Add this line to your shell profile (~/.zshrc or ~/.bashrc):"
    echo "           export PATH=\"$BIN:\$PATH\""
    echo "         It takes effect in new terminals. Until then, run rc as $BIN/rc"
    if [ -n "$found" ]; then
      echo "WARNING  another 'rc' is already on your PATH: $found"
      echo "         Put $BIN before it, or 'rc' will keep running that one."
    fi ;;
esac

if [ $status = 0 ]; then
  echo
  echo "Installed. Next, check a computer:  rc doctor <computer>"
fi
exit $status
