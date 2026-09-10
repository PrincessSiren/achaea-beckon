# AchaeaBeckon

A whitelist for who is allowed to move you.

Someone beckons. If they are on your list you follow them automatically; if they
are not, you get a red line naming them and nothing is sent.

**Nobody is trusted out of the box.** The list is the whole package, and a list
of people who may move your character is not something to ship pre-populated.
Until you add a name, every beckon is a red line and nothing is sent.

## Install

Install `AchaeaBeckon.mpackage` — from the
[latest release](../../releases/latest), or by running `python3 build.py`
yourself. Then add the people you actually follow:

```
beckonlist add Vellis: raids
beckonlist on
```

A release is one pinned version: it is tagged `v<version>`, the `.mpackage`
attached to it is built from that tag, and `beckonlist` prints the same version
back. The version alone cannot tell you whether Mudlet is running what is on
disk, though — it says what you expect whether or not anything was rebuilt.
`beckonlist diag` prints the build stamp for that, the one `build.py` printed
when it built the package. If the two differ, Mudlet is running an older
install.

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

Why it is built this way — the whitelist, the line it watches for, what it will
not do — is in [docs/](docs/). To send a patch, see
[CONTRIBUTING.md](CONTRIBUTING.md).

## Licence

GPL-3.0-or-later. See [LICENSE](LICENSE), which is also shipped inside the
built `.mpackage` -- Mudlet's package format has no licence field, so the
file is the only way the terms reach anyone who installs it.

You may use, change and pass this on. If you pass on a changed version it
has to stay under the same licence, with its source available.
