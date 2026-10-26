---
description: turning a name into the one thing it means here and now
requires: [name, layer, provides]
---

# resolve

resolving a [[name]] looks it up through the [[layer]]s, nearest first. the
first match wins. if nothing has the name itself, whatever [[provides]] it
is used.

the same name can resolve differently in two places, and that's the point:
the place is part of the input.
