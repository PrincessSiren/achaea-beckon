# Where the list is saved

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
comes back empty, and the next edit writes that emptiness over the file.

Settings are filtered through the defaults by name *and* type on the way in, so
a setting dropped in a later version cannot come back to life out of an old
file.

A re-add is not an erasure: `beckonlist add Vellis` typed again keeps the
reason and the date recorded the first time, unless you type a new reason.
