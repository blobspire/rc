---
name: other-computers
description: Start, list, and stop Claude Code Remote Control sessions on the user's other computers with the `rc` shell command. Use when the user wants to run or kick off a task or agent on another machine they name ("start an agent on my desktop to...", "run this on <computer>"), open a session there, see what's running on their other computers, or hand a long job to another machine. Also use to set rc up for a new computer, or when rc reports a problem.
user-invocable: false
---

<!-- user-invocable: false keeps this skill out of the / menu, so Claude Code's own /rc
     (Remote Control) keeps working. Claude still uses the skill when it's relevant. -->


# rc: sessions on the user's other computers

`rc` starts `claude --remote-control <name>` inside tmux on another computer over SSH. The
session keeps running after SSH disconnects, and the user drives it from claude.ai, the Claude
app, or a terminal through its control URL.

## Commands

```bash
rc <computer> [name] -p "<task>"   # start in the background with a first prompt; prints the control URL
rc <computer> -d <name>            # start in the background with no prompt
rc <computer>                      # list sessions there, with control URLs
rc <computer> -s <name>            # show the end of a session's screen: what Claude last said
rc <computer> -k <name>            # stop a session (only ones you started, or when the user asks)
rc ls                              # sessions on every computer the user has set up
rc doctor <computer>               # end-to-end check that explains how to fix problems
```

If `rc --version` doesn't print an rc version (rc was just installed, or another program is
called `rc`), use `~/.local/bin/rc` instead.

Sessions start in the computer's configured folder. Pass `-C <folder>` only to start somewhere
else, such as a specific project. `-p -` reads the prompt from stdin, which is easiest for long
prompts:

```bash
rc devbox fix-flaky-tests -C '~/code/api' -p - <<'EOF'
...the full task...
EOF
```

Exit codes: 0 means it worked. 1 means it failed and the message says why. 2 means the session
started but needs the user, for example to answer Claude Code's trust question; tell them the
exact command rc printed.

## Starting a task well

- The other session sees none of this conversation. Write the prompt as a complete brief: the
  project folder on that computer, the goal, constraints, and what "done" means. For a task
  whose results you'll need later, also say where to write them (a file path on that computer).
- With `-C`, use a folder that exists on that computer, and keep a leading `~` inside quotes so
  it means that computer's home.
- Give the user the control URL from rc's output; that's how they watch and steer the session.
- Names are short and unique. Without one, rc makes one from the task. If a session with that
  name already exists, rc does NOT send the prompt and exits 1; pick another name.
- Sessions start in auto mode, rc's default. The user can change it with `CLAUDE_ARGS` in that
  computer's rc settings.
- You usually can't message the remote session from here. To see what it said, run
  `rc <computer> -s <name>`; for longer results, read the file you asked it to write
  (`ssh <computer> cat <path>`).

## Rules

- Never attach (`rc <computer> <name>` with no `-d` or `-p`): attaching needs a terminal. rc
  notices when there's no terminal and starts the session in the background instead.
- Don't stop, reuse, or type into sessions you didn't start unless the user asks. `rc <computer>`
  lists the user's own sessions too.
- Don't answer Claude Code's "trust this folder" question or log in for the user. Tell them the
  command to run (rc prints it), and wait.
- A computer's network hook can switch the user's VPN (for example, turn Tailscale on or off).
  If rc's output shows a hook ran, mention it.

## Setup and problems

If rc isn't installed, a computer is new, or `rc doctor <computer>` reports a problem, follow
`SETUP.md` in the rc repo. `rc --version` prints where the repo is installed.
