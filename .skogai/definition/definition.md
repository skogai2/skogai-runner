---
description: a file that names one concept and says what it means
requires: [file, state, text, name]
---

# definition

a definition is a [[file]] whose [[name]] is the concept it defines. its
[[state]] holds the concept's relations to other concepts and its [[text]]
says what the concept means.

a definition names a concept, never what implements it. which implementation
is used is decided by [[provides]] and [[resolve]], not by the definition.

`definition/` is the vocabulary: everything of [[type]] definition. anything
that isn't defined here doesn't exist yet.
