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

If the rename itself fails -- on Windows it does when a `.bad` file from an
earlier time is still there -- nothing is written at all, since writing would
destroy the copy that could not be moved. Every change says it will be gone at
the next restart, `beckonlist status` says the list is not being saved, and
moving or deleting either file by hand lets the next change save. The same
warning follows a file that cannot be written for any other reason.

They are written as one envelope with both keys and read back the same way,
for a reason learned the hard way elsewhere: a key that is saved but not loaded
comes back empty, and the next edit writes that emptiness over the file.

Settings are filtered through the defaults by name *and* type on the way in, so
a setting dropped in a later version cannot come back to life out of an old
file.

A re-add is not an erasure: `beckonlist add Vellis` typed again keeps the
reason and the date recorded the first time, unless you type a new reason.

A near miss is not a re-add, though. `beckonlist add Slagnen` when `Slangen` is
already trusted makes a **second** entry -- the list is keyed by the exact name
-- and that second name is a stranger who may now move you. So `add` warns when
a new name is one slip of the keyboard from one already on the list: one letter
changed, added or dropped, or two neighbours swapped. It still adds the name,
because two real people can be named that closely, and the warning spells out
the `beckonlist rm` that undoes it.
