# Testing

Run these from the repository root:

```bash
luajit test_harness.lua
luajit -e "assert(loadfile('AchaeaBeckon.lua'))"
python3 build.py
```

The harness stubs Mudlet — including a small `rex_pcre` that translates the
handful of regex constructs these patterns use, so both the "compiles" and
"does not compile" paths are exercised — and drives lines through the real
trigger rather than calling the handler, because the trigger is where `matches`
comes from. It serves `matches` through an `__index` on the globals table, the
way Mudlet 5.1 builds it on first read, but without the 5.1 fix that lets
`rawget` see it there too. So the handler is held to a plain read, which every
Mudlet version answers. Trusted, untrusted, disarmed, yourself, a say quoting a
beckon, a name typed in the wrong case, the pattern being changed and rejected
and reset, and the whole list surviving a restart.

It proves the logic, not the line. The pattern still needs the real beckon text
in front of it — `SHOWEMOTE BECKON` in game, or a beckon copied off the screen.
