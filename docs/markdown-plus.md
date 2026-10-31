# Markdown+

How skogai declares intent and relationships, for agents. It describes the concept; field names are provisional until worked examples settle them.

## The idea

A Markdown file has two parts: frontmatter and body. Markdown+ gives each a distinct role.

- **Frontmatter is state.** Typed, machine-checkable facts: what this is called, what it depends on, what it reads, writes, owns and watches, what its defaults are.
- **The body is formatted text.** Prose for humans and agents: the purpose, the reasoning, how to use it, what each setting means.

One file holds both, so intent and the facts that make it actionable cannot drift apart. A human reads the body; a tool checks the frontmatter; an agent uses both.

## Why Markdown

- Agents read and write it fluently, without special tooling.
- It is plain text: diffable, reviewable and versioned like code.
- A description can start as prose alone and gain typed declarations as each one earns a precise meaning. Nothing has to be fully specified on day one.

This is the "+": Markdown becomes programmable one declaration at a time.

## Relationships

The core relationships a declaration can state:

| Relationship | Meaning |
| --- | --- |
| **depends on** | needs another named thing to exist |
| **reads** | uses a resource as input, without changing it |
| **writes** | changes a resource |
| **owns** | is the only thing allowed to write a resource |
| **watches** | reacts when a resource changes |
| **defaults** | supplies the base value for its settings |

Their rules follow from the principles in [why](why.md):

- Writing requires owning. You may only write what you own.
- Ownership is exclusive. Two declarations owning the same thing is a conflict.
- Paths stay in scope. A declaration describes its own surroundings and cannot reach outside them.
- Dependencies must resolve. Depending on something nothing provides is an answer, not a crash.
- Names are unique and lowercase, one segment each.

## Checking before acting

Declarations are only worth something if they are checked. A check is a pure read: it takes declarations and answers, for each one, valid or invalid with the reasons. It never changes anything, and asking twice gives the same answer.

Some checks need only one declaration (is the name well-formed, is every path in scope?). Others need all of them together (is every dependency provided, does anyone else own this?). Both kinds run before any effect, so a bad declaration is rejected while rejecting is still free.

## Declarations are not permissions

Frontmatter describes a boundary; it does not hold one. Declaring that something writes only one file does not stop it writing others. Enforcement belongs to the environment: what is reachable, what credentials exist, which tools are present. Declarations are the source the environment is prepared from, and the reference that effects are checked against afterwards.

## From declaration to work

Markdown+ is the format for every piece of prepared intent:

- a **module**: something skogai can do, its purpose in prose and its relationships in frontmatter
- a **workorder**: a unit of work, the user's intent in prose, with inputs, deliverables, dependencies, capabilities, writable scope and acceptance checks in frontmatter
- a **record**: an accepted intent or event, never edited, with revisions linked as new records

The same split runs through all of them: state that tools check, and text that explains why.
