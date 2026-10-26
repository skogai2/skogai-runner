---
description: subscribing to what a module writes, by leaving a named function in its folder
requires: [name, owns, writes]
---

# watches

to watch a module, put a named function in the folder it [[owns]] for that:
`logs/<type>/<name>.sh`. that file says "here is the name of my function
to call".

when the owner [[writes]] something of a type, it calls every name in that
type's folder. the writer publishes, the watchers subscribe, and the owned
folder is the hub between them. neither side knows who the other is; they
only share the folder.
