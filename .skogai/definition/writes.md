---
description: acting on what a module owns, by calling it by name
requires: [name, owns, interface]
---

# writes

the module that [[owns]] something is the only one that writes it, and the
way it writes is its [[interface]]: a named function anyone can call. to log
something you call `bin/log`; you never append to `log.jsonl` yourself.

writing is an invocation, and it's also a promise: when you call the name,
the owner acts, and everything that [[watches]] it hears about it. the
writer is the publisher.
