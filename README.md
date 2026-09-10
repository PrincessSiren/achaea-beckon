# AchaeaBeckon

A whitelist for who is allowed to move you. Someone beckons; if they are on the
list you follow them automatically, and if they are not you get a red line and
nothing is sent.

```
beckonlist                          -- status, then the command list
beckonlist status                   -- on or off, who is trusted, where the list is saved
beckonlist who                      -- who is allowed to beckon you, since when, and why
beckonlist add Jaison: raids        -- let a name move you; the note is optional
beckonlist rm Jaison                -- take a name back off
beckonlist on / off                 -- arm it, or report-only
beckonlist follow [cmd]             -- what a trusted beckon sends, `fol` by default
beckonlist pattern [regex|default]  -- the line it watches for; the capture is the name
beckonlist test <line>              -- paste a real beckon and see what it would do
beckonlist last                     -- the beckons seen this session, and what was done
beckonlist diag                     -- build stamp, live trigger, pattern, what it sends
```

The prefix is long on purpose. This is a package you set up once and then
forget, so nothing in it is worth a short name at the front of a command line —
and a bare `beckon` would be a guess at a word the game may well use itself.

Install `AchaeaBeckon.mpackage`, either from a release or by running
`python3 build.py` yourself. `beckonlist diag` prints the build stamp that
`build.py` printed; if they differ, Mudlet is running an older install.

**Nobody is trusted out of the box.** The list is the whole package, and a list
of people who may move you is not something to ship pre-populated. Until you
add a name, every beckon is a red line and nothing is sent.

## Why it follows rather than just warning

The alert on its own is the smaller half. A beckon is an offer to be somewhere
else, and the reason to automate it is that the four people who send you one are
the four people you were going to follow anyway — the whitelist is what makes
that safe to do without reading the line first. Everyone else gets named, in
red, and moves you nowhere.

It is also why the answer is a *list* and not a yes/no prompt. HELP 6.4 GROUPS
AND ENTOURAGES, under Group Movement:

> If you follow another adventurer, then when he moves, you'll move too
> (assuming you can).

Accepting a beckon is not one room change you could walk back. It hands
somebody where your character is until you LOSE them or walk away, so the
decision is about the person rather than the moment — which is a question you
can answer in advance, once, and that is what the list is.

`beckonlist off` leaves the reporting on and stops the sending, which is the
mode to run in while you are still deciding whether the pattern is right.

## What gets sent, and what does not

One command: `fol <name>`.

Not two. The snippet this package started from sent `lose <beckoner>` first, and
that names the wrong person. HELP 6.4 GROUPS AND ENTOURAGES:

> How to Form a Group
> --------------------
> FOLLOW someone! For example, if you wish to follow Crotalus, you'd simply
> FOLLOW CROTALUS and you'll be added to his group.
>
> How to Leave a Group
> ---------------------
> LOSE the person you are following (or is following you), or simply walk away
> from the group.

`LOSE` takes the person you are currently following — the leader you are
leaving — not the one who just beckoned you. Aimed at the beckoner it is a
no-op at best, and `FOLLOW` is what actually moves you into the new group.
Read it in game with `HELP 6.4`; the quote above is verbatim.

The command is a setting (`beckonlist follow`) because that reasoning is about
Achaea in 2026, and the reflex should outlive it.

## The line it watches for, and why the tail is still open

`SHOWEMOTE BECKON` prints an emote's text from every side at once, without
anyone having to perform it. That is what settled this:

```
When you BECKON:
You will see:    You make a beckoning motion.
Others will see: Aliapoe makes a beckoning motion.

When you BECKON at Vellis:
You will see:    You beckon to Vellis.
Vellis will see: Aliapoe beckons you to her.
Others will see: Aliapoe beckons Vellis to her.
```

So the line to watch for is `Aliapoe beckons you to her.` — actor's name first,
`you` as the object, ` to <pronoun>`, terminal period. That is exactly the
directed-emote shape `HELP 3.8 EMOTIONS` describes, which is why the pattern
originally read off that shape matches the real line unchanged:

```
^(\w+) beckons you
```

**The tail is still deliberately unanchored, and the same capture is why.** The
pronoun belongs to the *actor* — `to her` is Aliapoe's, not Vellis's, matching
3.8's "flutters **her** eyelashes" — so it changes with whoever beckoned you,
and `her` is the only form anything has actually printed. Anchoring
`(him|her|them)$` against a set nobody has seen would be a reflex that silently
never fires, which is the worst failure this package could have. Matching a
little too widely is safe because the whitelist is what decides.

The other two lines are worth as much as the first, because they are what the
pattern has to **miss**:

| line | who reads it | fires? |
| --- | --- | --- |
| `Aliapoe beckons you to her.` | the person beckoned | **yes** |
| `Aliapoe makes a beckoning motion.` | onlookers, untargeted | no |
| `Aliapoe beckons Vellis to her.` | onlookers, targeted | no |

An untargeted beckon does not contain "beckons" at all, and an onlooker's copy
of a targeted one puts the target's name where the pattern needs `you`. Both
are in the harness. That is the argument for `SHOWEMOTE` over waiting to be
beckoned: being on the receiving end shows you the line that must fire and
leaves the two that must not as guesses.

The capture is verbatim game output. Type `SHOWEMOTE BECKON` in game to
print all three perspectives again.

It remains a setting rather than a constant, because a capture settles what the
game prints today and this reflex should outlive that:

```
beckonlist test Jaison beckons you to her.
```

`beckonlist test` runs the current pattern against that text, says who it would
name and what it would send, and **sends nothing** whatever it decides.
`beckonlist pattern <regex>` installs and persists a replacement;
`beckonlist pattern default` puts the shipped one back.

This is why the trigger is created at runtime with `tempRegexTrigger` rather
than declared as a `<Trigger>` element in the XML: a declared trigger's pattern
is fixed at install time, and this one has to be correctable in game without a
rebuild.

Both `beckonlist test` and the check `beckonlist pattern` runs before
installing anything use `rex_pcre`, which is Mudlet's own PCRE binding and the
same engine the trigger compiles with. Mudlet only *warns* when that module is
missing, so both degrade to saying so rather than failing.

## Two things it will not do

- **It will not follow you.** A beckon naming your own character is ignored —
  the reflex knows your name from `gmcp.Char.Name`, and `fol <yourself>` is not
  a command worth being able to send by accident.
- **It does not read your ALLY list.** Orion's `ori.allies` / `ori.enemies` and
  its name database are read if Orion is loaded, one-way and optionally, to put
  "Blademaster, Mhaldor, enemy" beside the name on the alert. That is shown,
  never obeyed. An ally list is a courtesy extended for other reasons entirely,
  and this list is specifically about who may move your character; they are not
  the same question and conflating them is how the wrong person moves you.

## Persistence

The trusted list and the settings persist to `achaea-beckon.lua` in the profile
directory (`getMudletHomeDir()`), which is **outside the package**. Installing a
new version of AchaeaBeckon over an old one replaces scripts and aliases and
touches nothing in that directory, so the list survives a restart, a reinstall
and an update. `beckonlist status` prints the path and says whether the file was
there at startup and how many names came out of it — the point being that you
can check after an update rather than take this paragraph's word for it.

The one case where saving could lose the list is a file that will not parse:
it loads nothing, and a naive save would then write an empty list over the only
copy of the names. It is never overwritten. The unreadable file is renamed to
`achaea-beckon.lua.bad`, the fresh state is written beside it, and both the
load and the rename say so on screen.

They are written as one envelope with both keys and read back the same way,
for a reason learned the hard way elsewhere: a key that is saved but not loaded
comes back empty, and the next edit writes that emptiness over the file. Settings are filtered through the defaults by name *and* type on the way
in, so a setting dropped in a later version cannot come back to life out of an
old file.

A re-add is not an erasure: `beckonlist add Jaison` typed again keeps the
reason and the date recorded the first time, unless you type a new reason.

## Testing

Run these from this directory:

```bash
luajit test_harness.lua
luajit -e "assert(loadfile('AchaeaBeckon.lua'))"
python3 build.py
```

The harness stubs Mudlet — including a small `rex_pcre` that translates the
handful of regex constructs these patterns use, so both the "compiles" and
"does not compile" paths are exercised — and drives lines through the real
trigger rather than calling the handler, because the trigger is where `matches`
comes from. Trusted, untrusted, disarmed, yourself, a say quoting a beckon, a
name typed in the wrong case, the pattern being changed and rejected and reset,
and the whole list surviving a restart.

It proves the logic, not the line. The pattern still needs the real beckon text
in front of it — `SHOWEMOTE BECKON` in game, or a beckon copied off the screen.

## Licence

GPL-3.0-or-later. See [LICENSE](LICENSE), which is also shipped inside the
built `.mpackage` -- Mudlet's package format has no licence field, so the
file is the only way the terms reach anyone who installs it.

You may use, change and pass this on. If you pass on a changed version it
has to stay under the same licence, with its source available.
