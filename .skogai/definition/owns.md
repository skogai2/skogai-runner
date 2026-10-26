---
description: the files and folders a module is the only writer of
requires: [name, state, type, module]
---

# owns

`owns` is a [[state]] key that lists paths. the [[module]] that owns a path
is its only writer. everyone else acts on it through what the module
[[writes]], never by writing it themselves.

a module can own a folder as well as a file. owning a folder makes the module
that folder's [[type]]: its class, template, namespace or parent. it decides
what belongs in the folder and what shape it has. `definition/` is owned
that way.

inside an owned folder, a name that carries another module's name belongs to
that module. this is how a module [[watches]] another one: the folder is the
owner's, and the subscription inside it is the subscriber's.
