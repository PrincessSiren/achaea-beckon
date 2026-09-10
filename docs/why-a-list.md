# Why a list, and why it follows

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

## Why the prefix is long

The prefix is long on purpose. This is a package you set up once and then
forget, so nothing in it is worth a short name at the front of a command line —
and a bare `beckon` would be a guess at a word the game may well use itself.

The alias *names* inside the package — `add`, `rm`, `who` — drop the noun for
the same reason: the prefix already carries it.
