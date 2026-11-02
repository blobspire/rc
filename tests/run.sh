#!/usr/bin/env bash
# End-to-end tests for rc. A fake ssh runs the "remote" side on this machine (separate HOME and
# tmux server) and a fake claude stands in for Claude Code, so nothing real is touched.
# Needs bash and tmux. RC_TEST_BASH picks the bash that runs rc (CI uses macOS /bin/bash 3.2).
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
command -v tmux >/dev/null || { echo "tmux is required to run the tests"; exit 1; }
RUN_BASH=${RC_TEST_BASH:-bash}

T=$(mktemp -d "${TMPDIR:-/tmp}/rc-test.XXXXXX")
export RC_TEST_REMOTE_HOME=$T/remote RC_TEST_TMUX=$T/tmux RC_TEST_DOWN=$T/down RC_TEST_LOG=$T/ssh.log
mkdir -p "$RC_TEST_REMOTE_HOME/.local/bin" "$RC_TEST_TMUX" "$RC_TEST_DOWN" "$T/bin" "$T/home"
cp "$ROOT/tests/fake-ssh" "$T/bin/ssh"
cp "$ROOT/tests/fake-claude" "$RC_TEST_REMOTE_HOME/.local/bin/claude"
chmod +x "$T/bin/ssh" "$RC_TEST_REMOTE_HOME/.local/bin/claude"
export PATH="$T/bin:$PATH" HOME=$T/home RC_CONFIG_DIR=$T/config RC_WAIT=8
unset RC_DIR RC_ARGS XDG_CONFIG_HOME TMUX
cleanup() { TMUX_TMPDIR=$RC_TEST_TMUX tmux kill-server >/dev/null 2>&1; rm -rf "$T"; }
trap cleanup EXIT

passed=0 failed=0
OUT="" CODE=0
run() { OUT=$("$RUN_BASH" "$ROOT/rc" "$@" </dev/null 2>&1); CODE=$?; }
check() { # check <description> <command...>
  local what=$1; shift
  if "$@"; then passed=$((passed + 1)); else
    failed=$((failed + 1))
    printf 'FAIL: %s\n  exit %s, output:\n%s\n' "$what" "$CODE" "$(printf '%s\n' "$OUT" | sed 's/^/    /')"
  fi
}
has()  { case $OUT in *"$1"*) return 0 ;; esac; return 1; }
lacks() { ! has "$1"; }
code() { [ "$CODE" = "$1" ]; }
alive() { TMUX_TMPDIR=$RC_TEST_TMUX tmux has-session -t "=$1" 2>/dev/null; }
# The arguments the fake claude received for a session, compared byte for byte.
args_are() { local f=$RC_TEST_REMOTE_HOME/args-$1; shift; cmp -s "$f" <(for a in "$@"; do printf '%s\0' "$a"; done); }
R=$RC_TEST_REMOTE_HOME

# --- basics -------------------------------------------------------------------------------
run;                    check "no arguments prints usage" code 0
                        check "usage mentions -p" has "-p \"<task>\""
run --version;          check "--version" has "rc 0.1.0"
run box -x;             check "unknown option is an error" code 1
run 'bad name';         check "invalid computer name is an error" has "doesn't look like a computer name"

# --- doctor: a failed check doesn't leave its start folder behind --------------------------
echo "$R/rc" > "$R/untrusted-dirs"
run doctor box;         check "doctor reports the trust question" has "asking whether to trust"
                        check "...and exits 1" code 1
                        check "...and removes the folder it created" test ! -d "$R/rc"
rm -f "$R/untrusted-dirs"

# --- start, reattach, list, stop ----------------------------------------------------------
run box;                check "list on a new computer" has "(no sessions)"
                        check "computer is remembered" test -f "$T/config/computers/box"
run box -d alpha;       check "start detached" code 0
                        check "start prints the control URL" has "https://claude.ai/code/session_TEST_alpha"
                        check "start prints how to attach" has "Attach: rc box alpha"
                        check "default folder ~/rc is created and used" test "$(cat "$R/cwd-alpha")" = "$R/rc"
                        check "auto mode is on by default" args_are alpha --remote-control alpha --permission-mode auto
run box -d alpha;       check "starting it again reattaches" has "'alpha' is already running"
                        check "reattach still shows the URL" has "session_TEST_alpha"
run box;                check "list shows the session and URL" has "session_TEST_alpha"
run box -k alp;         check "stop needs the exact name" code 1
                        check "a prefix doesn't stop alpha" alive alpha
run box -k alpha;       check "stop" has "Stopped 'alpha'"
                        check "session is gone" eval '! alive alpha'
run box -d check email; check "multi-word names become one" has "Started 'check-email'"

# --- prompts ------------------------------------------------------------------------------
P=$'-starts with a dash, "double" and \'single\' quotes, $HOME, `backticks`, \\ and\na second line'
run box -d tricky -p "$P"
check "prompt with quotes, \$, backticks, newline arrives intact" \
  args_are tricky --remote-control tricky --permission-mode auto -- "$P"
run box -s tricky;      check "-s shows the end of a session's screen" has "session_TEST_tricky"
run box -s nope;        check "-s on a missing session exits 1" code 1
run box -p "Fix the flaky login tests, then open a PR"
check "a name is made from the prompt" has "Started 'fix-the-flaky-login-tests'"
run box -p "Fix the flaky login tests again"
check "made-up names don't collide" has "Started 'fix-the-flaky-login-tests-2'"
OUT=$(printf 'task from stdin\n' | "$RUN_BASH" "$ROOT/rc" box piped -p - 2>&1); CODE=$?
check "-p - reads the prompt from stdin" args_are piped --remote-control piped --permission-mode auto -- "task from stdin"
run box tricky -p "another task"
check "a prompt for an existing name isn't sent" has "NOT sent"
check "...and exits 1" code 1
run box -d planner -p "plan it"
RC_ARGS="--permission-mode plan --effort high" run box -d planner2
check "RC_ARGS replaces the default permission mode" \
  args_are planner2 --remote-control planner2 --permission-mode plan --effort high

# --- things that need a person ------------------------------------------------------------
run box -d needs-trust; check "trust question is detected" has "waiting for you to trust"
                        check "...and exits 2" code 2
run box -d fresh-install; check "first-time setup is detected" has "needs first-time setup"
run box -d crash-now;   check "claude exiting is reported" has "claude exited right after starting"
                        check "...with its screen" has "something went wrong"
run box -d silent-one;  check "no URL is reported after the wait" has "No control URL after"
                        check "...and exits 2" code 2
run box;                check "the list explains a missing URL" has "(no control URL on screen)"

# --- folders ------------------------------------------------------------------------------
mkdir -p "$R/my project"
# shellcheck disable=SC2088  # rc expands ~ on the other computer; that's what's under test
run box -d spacey -C '~/my project'
check "-C with a space and ~" test "$(cat "$R/cwd-spacey")" = "$R/my project"
# shellcheck disable=SC2088
run box -d nowhere -C '~/does-not-exist'
check "a missing folder is an error" has "doesn't exist on box"
printf "DIR='~/my project'\n" > "$T/config/computers/box2"
run box2 -d fromconfig; check "DIR from settings" test "$(cat "$R/cwd-fromconfig")" = "$R/my project"

# --- attaching without a terminal ---------------------------------------------------------
run box attachme;       check "no terminal: starts in the background instead" has "Not attaching"
                        check "...and still starts it" alive attachme

# --- networks -----------------------------------------------------------------------------
printf 'NET="touch %s/hook-ran"\n' "$T" > "$T/config/computers/box3"
run box3;               check "the network hook doesn't run when SSH works" test ! -e "$T/hook-ran"
touch "$RC_TEST_DOWN/vpnbox"
printf 'NET="rm -f %s/vpnbox; echo hook says hi"\n' "$RC_TEST_DOWN" > "$T/config/computers/vpnbox"
run vpnbox;             check "the network hook runs when SSH fails" has "hook says hi"
                        check "...and then rc works" has "vpnbox:"
touch "$RC_TEST_DOWN/deadbox"
run deadbox;            check "unreachable without a hook explains NET" has "set NET in"
                        check "...and exits 1" code 1
printf 'SSH_HOST=box\n' > "$T/config/computers/alias"
run alias -d via-alias; check "SSH_HOST is used" has "Started 'via-alias' on alias"

# --- rc ls and doctor ---------------------------------------------------------------------
run ls;                 check "rc ls lists every computer" has "vpnbox:"
                        check "rc ls shows sessions" has "check-email"
run doctor box;         check "doctor passes on a working computer" has "All good"
                        check "...and exits 0" code 0
run doctor deadbox;     check "doctor reports SSH failure" has "can't SSH"

# --- the skill must not take over Claude Code's /rc -------------------------------------------
OUT=$(awk 'NR == 1 && /^---$/ { f = 1; next } f && /^---$/ { exit } f' "$ROOT/skills/other-computers/SKILL.md"); CODE=0
check "the skill is hidden from the / menu (user-invocable: false)" has "user-invocable: false"
check "the skill isn't named rc" lacks "name: rc"

echo
echo "$passed passed, $failed failed"
[ "$failed" = 0 ]
