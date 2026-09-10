# Docs

The front README says what AchaeaBeckon does and lists the commands. These say
why it is built the way it is — each one is the reasoning behind a decision that
looks arbitrary until you know what it is guarding against.

- **[Why a list, and why it follows](why-a-list.md)** — why the answer is a
  whitelist rather than a yes/no prompt, what it deliberately will not do, and
  why it does not read your ALLY list.
- **[What gets sent, and what does not](what-it-sends.md)** — one command,
  `fol <name>`, and why the `lose <beckoner>` this was adapted from named the
  wrong person.
- **[The line it watches for](the-beckon-line.md)** — the capture behind the
  pattern, the two lines it has to *miss*, and why the tail is left unanchored.
- **[Where the list is saved](persistence.md)** — the file, and why an
  unreadable one is renamed rather than written over.
- **[Testing](testing.md)** — what the harness covers, and what it cannot.
