# The line it watches for, and why the tail is still open

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
beckonlist test Aliapoe beckons you to her.
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
