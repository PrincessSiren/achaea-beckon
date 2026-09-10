# AchaeaBeckon

A whitelist for who is allowed to move you.

Someone beckons. If they are on your list you follow them automatically; if they
are not, you get a red line naming them and nothing is sent.

**Nobody is trusted out of the box.** The list is the whole package, and a list
of people who may move your character is not something to ship pre-populated.
Until you add a name, every beckon is a red line and nothing is sent.

## Install

Install `AchaeaBeckon.mpackage` — from a release, or by running `python3
build.py` yourself. Then add the people you actually follow:

```
beckonlist add Jaison: raids
beckonlist on
```

`beckonlist diag` prints the build stamp that `build.py` printed. If the two
differ, Mudlet is running an older install.

## Commands

| Command | What it does |
| --- | --- |
| `beckonlist` | Status, then this list |
| `beckonlist status` | On or off, who is trusted, where the list is saved |
| `beckonlist who` | Who may beckon you, since when, and why |
| `beckonlist add <name>[: note]` | Let a name move you; the note is optional |
| `beckonlist rm <name>` | Take a name back off |
| `beckonlist on` / `off` | Arm it, or report without sending |
| `beckonlist follow [cmd]` | What a trusted beckon sends — `fol` by default |
| `beckonlist pattern [regex\|default]` | The line it watches for; the capture is the name |
| `beckonlist test <line>` | Paste a real beckon and see what it would do, sending nothing |
| `beckonlist last` | The beckons seen this session, and what was done about each |
| `beckonlist diag` | Build stamp, live trigger, pattern, what it sends |

`off` is the mode to run in while you are still deciding whether the pattern is
right: it keeps the reporting and stops the sending.

## Why it is built this way

Each of these is the reasoning behind a decision that looks arbitrary until you
know what it guards against.

- **[Why a list, and why it follows](docs/why-a-list.md)** — why a whitelist
  rather than a prompt, and why it does not read your ALLY list.
- **[What gets sent, and what does not](docs/what-it-sends.md)** — one command,
  and why the `lose <beckoner>` this was adapted from named the wrong person.
- **[The line it watches for](docs/the-beckon-line.md)** — the capture behind
  the pattern, the two lines it has to *miss*, and why the tail is unanchored.
- **[Where the list is saved](docs/persistence.md)** — and why an unreadable
  file is renamed rather than written over.
- **[Testing](docs/testing.md)** — what the harness covers, and what it cannot.

## Licence

GPL-3.0-or-later. See [LICENSE](LICENSE), which is also shipped inside the
built `.mpackage` -- Mudlet's package format has no licence field, so the
file is the only way the terms reach anyone who installs it.

You may use, change and pass this on. If you pass on a changed version it
has to stay under the same licence, with its source available.
