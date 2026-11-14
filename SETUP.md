# Setting up rc (instructions for an agent)

You're setting up `rc` for a user so they can start Claude Code Remote Control sessions on their
other computers. Work through the steps in order. Run the commands yourself where you can. When
a step needs the user's hands (a password, a login, a trust question), tell them exactly what to
type and where, then wait for them.

Ground rules:

- Ask before installing software on any computer, and before anything that needs `sudo`.
- Don't answer Claude Code's "trust this folder" question, log in, or type into sessions for the
  user.
- Don't stop tmux sessions you didn't create, and don't edit `~/.claude.json` or Claude Code
  settings on any computer.
- Commands that ask for a password or show a full-screen program (`ssh-copy-id`, `ssh -t ...`,
  attaching to a session) need a real terminal. Ask the user to run those in a terminal window.

## 1. Install rc on this computer

```bash
if [ -d ~/.local/share/rc/.git ]; then
  git -C ~/.local/share/rc pull --ff-only
else
  git clone https://github.com/blobspire/rc ~/.local/share/rc
fi
~/.local/share/rc/install.sh
```

The installer links `rc` into `~/.local/bin` and rc's Claude Code skill (`other-computers`) into
`~/.claude/skills`. Claude Code picks up the skill without a restart. The skill has no slash
command, so `/rc` in Claude Code still starts Remote Control.

- **"isn't on your PATH".** Offer to add the line it prints to the user's shell profile
  (`~/.zshrc` for zsh, `~/.bashrc` for bash). The change only reaches new terminals, and this
  Claude Code session won't see it. So for the rest of setup, run `~/.local/bin/rc`, and write
  `~/.local/bin/rc` in any command you give the user, until they've opened a new terminal.
- **"another 'rc' is already on your PATH" or "comes before".** Tell the user. Another program
  named `rc` (such as the Plan 9 shell) would run instead. Use `~/.local/bin/rc` and offer to put
  `~/.local/bin` first in PATH.
- **"SKIPPED".** Show the user and ask what they want to do. Never delete their file.

Check it: `~/.local/bin/rc --version` prints `rc <version> (<where it's installed>)`.

## 2. Make sure SSH works without a password

For each computer the user named, this must succeed:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=10 <computer> true
```

If it fails, the error says why:

- **"Could not resolve hostname".** Ask the user for the computer's address and their username
  there. Add a `Host <computer>` block with `HostName` and `User` to `~/.ssh/config`, show it to
  them, and try again.
- **"Permission denied".** rc needs key-based login. If `ls ~/.ssh/id_*.pub` finds no key, offer
  to create one with `ssh-keygen -t ed25519`. Then the user runs `ssh-copy-id <computer>` in a
  terminal. It asks for their password on that computer once.
- **"Host key verification failed".** The user runs `ssh <computer>` once in a terminal and
  accepts the host key, after checking the fingerprint if they can.
- **Timeout or "No route to host".** The computer may be on another network. Ask how they
  normally reach it, then go to step 6.

## 3. Choose where sessions start

Do this before the first `rc doctor`. Claude Code asks once per folder whether to trust it, so
pick the folder first and answer that question once.

Ask the user where sessions on that computer should start: usually the folder their projects
live in, such as `~/code`. Its subfolders become projects: `rc <computer> api fix-tests` starts
session `fix-tests` in `~/code/api`, and trusting `~/code` once covers every project inside it.
To see which folders Claude Code already trusts there:

```bash
ssh <computer> "python3 -c \"import json,os; print('\n'.join(k for k,v in json.load(open(os.path.expanduser('~/.claude.json'))).get('projects',{}).items() if v.get('hasTrustDialogAccepted')))\""
```

A trusted folder works right away. If they don't care, the default `~/rc` is fine, though it
needs the trust question answered once (step 4). Never use their home folder: Claude Code never
remembers trusting it.

Write the choice to the computer's settings file. Create the file if it doesn't exist yet; rc
creates it with every option commented out the first time it reaches the computer.

```bash
mkdir -p ~/.config/rc/computers
echo "DIR='~/code'" >> ~/.config/rc/computers/<computer>
```

Keep the quotes, so `~` means that computer's home. Absolute paths like `DIR='/home/sam/code'`
work too.

## 4. Run rc doctor and fix what it reports

```bash
~/.local/bin/rc doctor <computer>
```

Fix each FAIL line, then run doctor again until it ends with "All good". Doctor starts and stops
a short test session; it appears briefly in the user's claude.ai session list.

- **tmux isn't installed.** Ask, then install it. On Debian or Ubuntu that's
  `sudo apt install -y tmux`, which usually needs a password, so the user runs
  `ssh -t <computer> sudo apt install -y tmux` in a terminal. On a Mac with Homebrew:
  `ssh <computer> 'brew install tmux'`.
- **Claude Code isn't installed, or is too old.** Ask, then install it:
  `ssh <computer> 'curl -fsSL https://claude.ai/install.sh | bash'`. To update an old one:
  `ssh <computer> claude update`.
- **Claude Code hasn't been set up yet.** The user runs `ssh -t <computer> claude` in a terminal,
  picks a theme, logs in with their claude.ai account (Pro, Max, Team, or Enterprise), then
  types `/exit`.
- **Asking whether to trust the folder.** If the user would rather use a folder that's already
  trusted, change `DIR` (step 3) and run doctor again. Otherwise the user runs the command doctor
  printed (`~/.local/bin/rc <computer> setup -C '<DIR>'`) in a terminal, chooses "Yes, I trust
  this folder", and types `/exit` (or keeps working in that session; `Ctrl-b d` detaches and
  leaves it running). Claude Code remembers the answer for that folder and the projects inside
  it. If they detached, stop the session when it's no longer needed:
  `~/.local/bin/rc <computer> -k setup`.
- **Remote Control isn't available.** Show the user the screen doctor printed and match the
  message to https://code.claude.com/docs/en/remote-control#troubleshooting. Common causes: an
  API key login instead of claude.ai, a Team or Enterprise organization where an Owner hasn't
  turned Remote Control on, or a variable like `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` (doctor
  warns about these).
- **A Mac that goes to sleep (warning).** Its sessions go offline while it sleeps. Tell the user,
  and offer `sudo pmset -c sleep 0` (keep it awake on power), which they run in a terminal.

## 5. Other settings (only if needed)

The settings file `~/.config/rc/computers/<computer>` also takes:

```bash
SSH_HOST='...'        # only if the ssh name differs from the name the user types
NET="..."             # only for step 6
CLAUDE_ARGS='...'     # flags for claude; rc's default is --permission-mode auto
```

## 6. Networks (only if SSH works on some networks but not others)

Ask the user how they reach the computer from outside its network, then set `NET` to a command
that brings that network up. rc runs it only when SSH fails, then tries SSH again.

- **Tailscale:** `NET="$RC_HOME/examples/network/tailscale-up.sh"`
- **Cloudflare WARP or Zero Trust:** `NET="$RC_HOME/examples/network/cloudflare-warp.sh"`
- **Anything else:** write a small script in `~/.config/rc/` that connects and exits 0 once the
  network is up. It must be safe to run when the network is already up, and it shouldn't print
  secrets. Point `NET` at it.

Don't disconnect the user's VPN to test the hook unless they agree. Running `rc doctor` while
the network is up only proves SSH works.

## 7. Finish

Tell the user what's set up and how to use it, writing `~/.local/bin/rc` instead of `rc` if they
haven't opened a new terminal since fixing PATH:

- `rc <computer> <name>` starts a session and attaches; `Ctrl-b d` detaches and leaves it running.
- `rc <computer> -p "<task>"` starts a session with a task and prints its control URL.
- `rc <computer> <project> <name>` starts in a project folder inside `DIR` (for example
  `rc <computer> api fix-tests`).
- `rc ls` lists sessions everywhere, and sessions appear at https://claude.ai/code and in the
  Claude app.
- They can ask Claude Code to start agents on that computer; rc's skill handles it.
