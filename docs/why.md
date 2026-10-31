# Why

The reasoning behind skogai-runner, for agents. It explains intent, not implementation; which tool fulfils a concept can change without changing anything here.

## The problem

An agent starts every session knowing nothing about the work in front of it. Someone has to tell it what the user wants, which files matter, what it may touch, which tools to use, and how to know when it is done. Today that is done with prose: instructions, rules, reminders, repeated every session and enforced by hope.

Prose does not scale and does not hold. Instructions drift, contradict each other, and get forgotten mid-session. A rule saying "never write outside this directory" is a request; a filesystem that refuses the write is a guarantee.

skogai-runner exists to replace repeated prose with prepared work: intent, context, tools and boundaries declared once, checked before anything happens, and enforced by the environment.

## Why a command runner

A command is the smallest unit of work that both a human and an agent can understand the same way: a name, typed arguments, a result, and an exit status. That makes commands the natural shared interface.

- **One interface, two users.** The same declaration that gives a human help text and completion gives an agent a tool definition. There is no separate "agent API" to drift away from what humans use.
- **The interface is the validation.** A command that declares its arguments rejects bad ones before running. Invalid input never reaches the work.
- **Commands compose.** Small commands with explicit inputs and outputs can be chained, tested and replaced one at a time.

"Yet another command runner" is fair. The difference is not how commands run but what surrounds them: declared intent, relationships between pieces, ownership of what they write, and a record of what happened.

## Principles

Each principle below exists because its absence caused real friction.

### Prepare the work, don't instruct the worker

An agent should start with everything already in place: the intent, the relevant files, the expected deliverables, the tools it needs and nothing it doesn't. Freedom inside a prepared scope beats a long list of prohibitions around an open one.

### Enforce through capability, not through text

What an agent must not do should be impossible, not forbidden. Access, credentials and available tools define what can happen. Declarations describe the boundary; the environment holds it.

### Rejection is a value

Almost all possible input is wrong, so rejecting it is the normal path, not a failure. A check that says "invalid, because …" has succeeded at its job. Errors are reserved for the unexpected: a missing dependency, a malformed request. Machine-readable answers go to one stream, diagnostics to another, and they never mix.

A rejection should not reveal what exists. Asking about something that is there and something that is not must not leak the difference.

### Decide, then act

Decisions are pure: given the same inputs they give the same answer and touch nothing. Effects come after, separately, and only when the decision allows them. This makes every decision checkable on its own and every effect explainable by the decision behind it.

### Repeating is safe

Running an operation twice must not double its effects. An operation has an identity; the same identity means the same outcome. Retrying something whose effect is uncertain is never done blindly.

### Intent and history are immutable

Accepted intent and recorded events are never edited. A correction is a new record linked to the old one. Summaries, views and inboxes are derived and can always be rebuilt. Immutability applies to records, not to every file: configuration and owned outputs change, but only through declared operations.

### State is a diff on a base

Every setting has a default. The system supplies the base; each layer above it — user, project, local — applies a difference. Any value can be traced to the layer that set it.

### Ownership before writing

Nothing writes a file it does not own. Ownership is declared, two things cannot own the same thing, and writing outside what you own is rejected. What belongs to another tool is pointed at, offered, never taken over.

### Trust existing systems

Version control, package managers, environment managers and the shell already solve hard problems well. Use them where they fit; build only the gap they leave, and only after the gap is demonstrated.

### Primitive first

Files, standard streams, exit codes and explicit invocation come first. Services, watchers, sockets and buses come when a concrete requirement demands them and the simpler form demonstrably fails.

### Names carry meaning

Names are lowercase and one segment. Separators express relations between names, never structure inside one. A name says what something is, never how it is built or when it was made.

### Concepts, not mechanisms

Definitions name concepts — "on change", "at session end", "owns" — never the mechanism that currently implements them. Mechanisms are replaceable; concepts are the contract.

## What this buys

- An agent that starts with the right context instead of discovering it.
- Mistakes caught as rejections before they become effects.
- Work that can be repeated, resumed and explained.
- A result that traces back to the intent that asked for it.

See [history](history.md) for how the project got here and [Markdown+](markdown-plus.md) for how intent and relationships are declared.
