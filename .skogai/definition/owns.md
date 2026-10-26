---
description: the paths a module is responsible for writing
requires: [name, state, module]
---

# owns

`owns` is a [[state]] key that lists paths. the [[module]] that owns a path
is the one that writes it. everyone else only reads it or [[watches]] it.

a path in `owns` can carry relations: `scripts/<type>/<module>/<name>.sh`
says a module owns one script per name of a type.
