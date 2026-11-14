# rc

[![test](https://github.com/blobspire/rc/actions/workflows/test.yml/badge.svg)](https://github.com/blobspire/rc/actions/workflows/test.yml)

Start Claude Code sessions on your other computers with one command, then drive them from
claude.ai, the Claude app on your phone, or your terminal.

```console
$ rc devbox fix-tests -C '~/code/api' -p "Run the test suite and fix whatever fails"
Started 'fix-tests' on devbox in /home/you/code/api
Control URL: https://claude.ai/code/session_01AbC...
Attach: rc devbox fix-tests
```

`rc` connects to the computer over SSH and starts
[`claude --remote-control`](https://code.claude.com/docs/en/remote-control) inside tmux there.
The session keeps running when you close your laptop, and it shows up in your session list on
claude.ai and in the Claude app, so you can check on it and steer it from anywhere.

- **One command from a cold laptop.** If the computer is only reachable over a VPN or tunnel,
  `rc` brings that up first, and only when it's needed.
- **Attach or don't.** `rc devbox work` drops you into the session. Add `-p "<task>"` to hand
  it a task and walk away.
- **Name the project, not the path.** With your repos in one folder, `rc devbox api fix-tests`
  starts session `fix-tests` in `~/code/api`.
- **Agents can use it too.** The included Claude Code skill lets Claude start sessions on your
  other computers: "start an agent on devbox to profile the import job".
- **Catches the usual snags.** It prints the control URL, and it tells you when a session is
  stuck on Claude Code's "trust this folder" question, isn't logged in, or can't use Remote
  Control. `rc doctor` checks a computer end to end.

## Set it up

Paste this into Claude Code on your laptop:

> Set up rc for my computer `<name>` by following https://github.com/blobspire/rc/blob/main/SETUP.md

The agent installs `rc`, checks SSH, tmux, and Claude Code on that computer, and tells you
exactly what to do for anything that needs you, like logging in.

Or do it by hand:

```bash
git clone https://github.com/blobspire/rc ~/.local/share/rc
~/.local/share/rc/install.sh
rc doctor <computer>
```

If the installer says `~/.local/bin` isn't on your PATH, add the line it prints to your shell
profile and open a new terminal (or run `~/.local/bin/rc` until you do). To update later:
`git -C ~/.local/share/rc pull`.

### Requirements

- **This computer:** macOS or Linux with `bash` and `ssh`.
- **Each other computer:** macOS or Linux that `ssh <computer>` reaches without a password
  prompt (key-based login), with `tmux` and [Claude Code](https://code.claude.com/docs/en/setup)
  2.1.51 or later installed.
- **Claude login on each computer:** a claude.ai account on Pro, Max, Team, or Enterprise.
  Remote Control doesn't work with API keys, Bedrock, Vertex, or Foundry. On Team and Enterprise,
  an Owner has to turn Remote Control on in the
  [Claude Code admin settings](https://claude.ai/admin-settings/claude-code).

## Use it

| Command | What it does |
| --- | --- |
| `rc devbox work` | Start session `work` on devbox (or reattach to it) and attach |
| `rc devbox -d work` | Start it in the background and print its control URL |
| `rc devbox -p "<task>"` | Start a session with a first prompt; it's named after the task |
| `rc devbox work -p "<task>" -C '~/code/api'` | Same, with a name and a starting folder |
| `rc devbox api fix tests` | Start session `fix-tests` in the project folder `api` inside `DIR` (see below) |
| `rc devbox` | List sessions on devbox, with their control URLs |
| `rc devbox -s work` | Show the end of `work`'s screen, to see what Claude last said |
| `rc devbox -k work` | Stop session `work` |
| `rc ls` | List sessions on every computer you've used |
| `rc doctor devbox` | Check devbox end to end and explain how to fix problems |

`-p -` reads the prompt from stdin. Inside an attached session, detach with `Ctrl-b d`; the
session keeps running. When `claude` exits, the tmux session stays open so you can read what it
printed; press Enter for a shell on that computer, or `Ctrl-D` to close the session.

### Projects

Point `DIR` at the folder that holds your repos, and name a project as the first word. If that
word is a folder inside `DIR` on that computer, the session starts there and the remaining words
are its name. With `DIR='~/code'`:

- `rc devbox api fix tests` starts session `fix-tests` in `~/code/api`.
- `rc devbox api` starts (or reattaches to) session `api` in `~/code/api`.
- `rc devbox api -p "<task>"` starts a session named after the task in `~/code/api`.

When the first word isn't a folder there, every word is part of the name. The project isn't part
of the session name, so `rc devbox -k fix-tests` stops it. `-C` turns the lookup off. Claude
Code's answer to the trust question for `DIR` covers the projects inside it, so a new repo there
works right away.

## Settings

Everything is optional. `rc <computer>` works for any name in your `~/.ssh/config`. A computer
you've used gets a settings file at `~/.config/rc/computers/<computer>` with every option
commented out:

```bash
SSH_HOST='devbox.example.com'      # what to pass to ssh, if different from the name you type
DIR='~/code'                       # folder sessions start in; its subfolders are projects (quote ~)
NET="$RC_HOME/examples/network/tailscale-up.sh"   # runs only when the computer can't be reached
CLAUDE_ARGS='--permission-mode auto'               # flags for claude
```

The same keys in `~/.config/rc/config` apply to every computer. For one run, `RC_DIR` sets the
folder and `RC_ARGS` adds flags, for example `RC_ARGS="--model opus --effort high" rc devbox work`.

Without a `DIR`, sessions start in `~/rc` on that computer, which rc creates. Pick the folder
that holds your projects if you have one. Claude Code asks once per folder whether you trust it, and never
remembers that answer for your home folder, so rc doesn't start sessions there.

### Auto mode

Sessions start with `--permission-mode auto`, so Claude works through a task without stopping
for routine permission prompts while a classifier blocks risky actions. If auto mode isn't
available for your plan, model, or organization, Claude Code starts the session in normal mode
instead. To change it for a computer, set `CLAUDE_ARGS='--permission-mode default'` in its
settings, or put that in `~/.config/rc/config` for all of them.

Anyone who can use your Claude account can drive these sessions from claude.ai, with that
computer's access. Keep your account secured, and consider
[Trusted Devices](https://code.claude.com/docs/en/remote-control#trusted-devices).

## Networks

Most computers need nothing here. If a computer is only reachable over a VPN or tunnel, give it a
network hook: a command that brings the network up. rc tries SSH first and runs the hook only if
SSH fails, so two computers on different networks don't fight each other. After the hook, rc
tries SSH again.

Two examples come with rc:

- [`examples/network/tailscale-up.sh`](examples/network/tailscale-up.sh) starts Tailscale and
  keeps your Tailscale settings.
- [`examples/network/cloudflare-warp.sh`](examples/network/cloudflare-warp.sh) connects
  Cloudflare WARP (for example, Zero Trust) and waits for it.

Point `NET` at one of them, or at your own script. A hook should exit 0 once the network is up,
and be safe to run when it's already up.

## Using it from Claude Code

`install.sh` also installs a Claude Code skill, `other-computers`. It doesn't add a slash
command, so Claude Code's own `/rc` (its shortcut for `/remote-control`) keeps working. Claude
uses the skill when you ask for things like:

- "Start an agent on devbox to run the benchmarks in ~/code/engine and write a summary to bench.md"
- "What's running on my other computers?"

Claude writes the task as a complete brief, starts it with `rc <computer> -p`, and gives you the
control URL. It won't stop or type into sessions it didn't start unless you ask.

## Troubleshooting

Start with `rc doctor <computer>`. It checks SSH, tmux, Claude Code, the start folder, and
settings that turn Remote Control off, then starts and stops a test session.

- **"waiting for you to trust" the folder.** Run the attach command rc printed in a terminal,
  choose "Yes, I trust this folder", and detach with `Ctrl-b d`. Claude Code remembers the
  answer for that folder and the folders inside it.
- **"needs first-time setup".** Run `ssh -t <computer> claude` once in a terminal, pick a theme,
  and log in.
- **"Remote Control isn't available".** rc shows the session's screen. Match the message to the
  [Remote Control troubleshooting guide](https://code.claude.com/docs/en/remote-control#troubleshooting).
- **Sessions on a Mac go offline.** The Mac is probably asleep; `rc doctor` warns about this.
- **`rc` runs something else.** Another program called `rc` is earlier on your PATH;
  `install.sh` warns about this.

## How it works

`rc devbox work` runs one short script over SSH. On devbox it writes `~/.rc-sessions/work.sh`,
which runs `claude --remote-control work` in the start folder, and starts it in a tmux session
named `work`. Then it reads the session's screen until the control URL appears. Session names
match exactly, so `rc devbox -k lab` never stops `lab-2`. Nothing runs on the other computer
between commands except your sessions.

## Uninstall

```bash
~/.local/share/rc/install.sh --uninstall
rm -rf ~/.local/share/rc ~/.config/rc
```

## License

MIT
