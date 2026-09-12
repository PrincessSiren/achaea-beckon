# Contributing

Bug reports and ideas are welcome. So are patches, with the caveats below.

## Running it outside Mudlet

Everything here is stdlib Python and Lua 5.1. There is nothing to install.

```bash
luajit test_harness.lua                        # the harness
luajit -e "assert(loadfile('AchaeaBeckon.lua'))"   # syntax
python3 build.py                               # rebuild the package
```

Mudlet embeds **Lua 5.1**, and `luajit` is that exact dialect. A 5.4 parser will
accept things Mudlet rejects, so check with `luajit` rather than `lua`.

## The `.xml` is generated, and it is what gets installed

`AchaeaBeckon.xml` is built from `AchaeaBeckon.lua` by `build.py`. Never edit it
by hand, and **always rebuild after touching the `.lua`** — a `.lua` edited
without a rebuild ships a package that does not match its source, invisibly,
because the diff of the change itself looks fine. CI fails on this.

`build.py` stamps a short content hash into the package, which `beckonlist diag`
prints back. That is a hash rather than a timestamp on purpose: the `.xml` is
committed, so building twice with no source change has to produce a
byte-identical file.

`ALIASES` in `build.py` is the single source of truth for the commands. It
generates the XML aliases *and* the `beckonlist.COMMANDS` table the in-game help
prints, so the help cannot drift from what is installed. Adding a command is one
row there plus a function in the Lua.

## Where rules come from

This package is small because it is careful about one thing: **what it claims
about Achaea comes from what Achaea printed**, not from what anyone remembers.

- Cite the scroll or the command — `HELP 6.4`, `AB <skill>`, `SHOWEMOTE BECKON`.
  Naming the command matters more than quoting it, because the command still
  works after the quote goes stale.
- Read an `AB` scroll's footnote. The asterisked line at the bottom is repeatedly
  the one that matters while the body above it reads as settled.
- **Do not fill a table in from memory.** The clearest case is in the trigger
  pattern: the pronoun in `beckons you to her.` belongs to the *actor*, and only
  `her` has actually been seen printed. Anchoring `(him|her|them)$` against a set
  nobody has observed would be a reflex that silently never fires — the worst
  failure available here. The same rule is why nothing ships with a
  pre-populated trusted list.
- If you cannot cite it, say so in the PR. An open question recorded honestly is
  worth more than a rule that reads well.

## Testing

`test_harness.lua` stubs Mudlet and drives lines through the **real trigger**
rather than calling the handler directly, because the trigger is where `matches`
comes from and `matches[2]` is the easy thing to get wrong.

A green run means the logic holds. It does **not** mean the trigger fires against
a real beckon — no runner has Mudlet or a connection to the game. Treat any
change to the pattern as unverified until it has run in a real profile.

Both lines that must *not* match are in the harness alongside the one that must.
Keep it that way: a pattern that fires too widely is caught by the whitelist, but
one that never fires says nothing at all.

## Versions

`0.x`. Minor for a change in behaviour, patch for a fix to something already
released, and it moves **once per merged PR** rather than once per push —
bumping mid-review mints numbers for states nobody installed.

`M.VERSION` in the Lua is the only place it lives; `build.py` reads it.

## Releasing

Pushing a tag `v<version>` is what ships. `release.yml` runs the harness, refuses
a tag whose number `M.VERSION` does not claim, builds the `.mpackage` from that
tag, attaches it to the release, and publishes it to the Mudlet package
repository, which lands as a pull request there.

Then it announces the release in Discord, if — and only if — a `DISCORD_WEBHOOK`
secret is set on the repository. That is a channel webhook URL from Discord's
*Server Settings → Integrations → Webhooks*, and it is a secret rather than a
setting because it is a bearer credential: anyone holding it can post to that
channel as this package.

The announcement is the last step and the only one allowed to fail. By the time
it runs the release exists and the package is published, so a webhook that is
down is a message nobody got rather than a release that went wrong — it leaves a
warning and the run stays green. Re-running the job to get the message out would
ask the registry to publish the same version twice; post it by hand instead. A
fork has no secret, so the step skips there rather than notifying this
repository's channel about someone else's tag.
