---
description: a diff of state applied on top of the one below it
requires: [state, default]
---

# layer

a layer is [[state]] that holds only what differs from the layer below. the
bottom is the [[default]]; above it sit the system, the user, the project and
the moment, nearest last.

layers are applied in order and the last one wins. a closer layer shadows a
farther one the way an inner [[folder]] scope shadows an outer one, and
removing a key from a layer reveals the one beneath.
