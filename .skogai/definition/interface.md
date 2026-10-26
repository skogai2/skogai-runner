---
description: the types a command takes and gives back; the first of its three steps
requires: [name, state]
---

# interface

an interface says how something is used: its [[command]]s, the type of
everything each one takes (arguments, options, env, the tools it needs),
what it gives back, and what an error looks like. it's the contract between
whoever calls a thing and whatever [[provides]] it.

an interface is the same for people and agents. help, completion and
checking all come from the one description.

an interface is checked when the command is run, not only read. input that
doesn't fit the types never gets past it. how the contract is fulfilled is
not part of it.
