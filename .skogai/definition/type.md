---
description: a grouping of names; written as the folder they sit in
requires: [name, file]
---

# type

a type is a grouping. every [[name]] in a folder has the folder's type:
`definition/context.md` is the name `context` of type `definition`. listing
a folder lists everything of that type, so a type needs no index.

a folder is only ever a grouping or a relationship. nesting folders chains
relations, the same way `.` does in a key: `event/hooks/usermessage.sh` is
`usermessage`, of type `event`, as [[module]] `hooks` relates to it.

a type can be described by a [[file]] of its own: `definition/type.md` is
the type of types.
