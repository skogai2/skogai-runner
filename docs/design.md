# Design direction

The earlier plans remain active. The immediate priority is to get the absolute basics dependable enough to build on: functional composition, idempotency, immutable records, strong types, and small Unix tools with explicit interfaces. Then build out modular, self-sustaining bundles of functionality.

## The three pieces

**argc** is the interface for users and agents, including runtime validation and basic CLI facilities: parsing, help, completion, man pages, and JSON declarations. Tool declarations and REPL tooling should derive from that interface where possible. Integrations beyond what argc supplies need small, verified adapters.

**mise** supplies the development environment, dependencies, and development tasks. Alongside Git config, it is a candidate for configuration and key/value settings. The exact division remains open; each setting needs an authoritative owner, explicit precedence, and a discoverable origin.

**Markdown+** is the programmable description of intent. A module starts as a Markdown file whose body explains its purpose and whose typed frontmatter declares relationships: depends on a module, reads a resource, writes a file, owns a file, watches a file, or supplies a default. Define and enforce these relationships before building behavior on them.

## Prepare the work

The goal is to turn a workorder into the context, environment, and tools needed to carry it out. The agent should start with relevant files, the user's intent, expected deliverables, dependencies, capabilities, and acceptance checks already prepared.

For a Postgres/Supabase change, prepare the relevant schema and migrations, the requested change, access to the intended project, inspection and validation tools, and the required result. Expose the resources and capabilities appropriate to that work. Enforce scope through the environment rather than depending on repeated instructions about unacceptable actions.

Start with a hand-prepared workorder. Automate preparation after that example establishes what is required.

## Record intent and effects

The target is an append-only JSONL event log connecting message exchange, actions, tool use, outcomes, and file changes. Git provides the file diff. Read-only observations and external effects also need records because they do not necessarily produce a diff.

At the end of a workorder, session, or PR, the records should support an explanation and a commit describing the change and its intent. Recording an event does not require making a commit for every tool call.

Accepted workorders and events are immutable records. Corrections and changed intent create linked revisions. Generated summaries and inbox views can be rebuilt from those records. Configuration, source files, and owned outputs can change through declared operations; immutability does not mean freezing every file.

## Communication stays primitive

Publish/subscribe semantics may help modules react to events. Begin with files and explicit commands. A Markdown inbox can show pending work, but an unstructured append alone does not establish delivery, acknowledgement, ordering, concurrency, or retry behavior.

The first example uses one writer, an explicit invocation, and no background service. Add polling, watchers, concurrent writers, sockets, or an API when a demonstrated requirement justifies them. Establish event identity, validation, duplicate handling, and recovery before choosing more transport machinery.

## Stability means observable guarantees

| Property | What to establish |
| --- | --- |
| Functional composition | Explicit inputs and outputs; decisions can be checked separately from effects |
| Idempotency | Repeating an operation with the same identity does not duplicate its effects |
| Immutability | Accepted intent and events remain intact; revisions link to earlier records |
| Strong types | Invalid structures and incompatible relationships fail before effects |
| Unix composition | Small tools exchange inspectable data and use predictable exit codes |
| Capability scope | Filesystem access, credentials, and tools enforce permitted effects |
| Recovery | Failure preserves existing state where possible and reports partial external effects |
| Provenance | A deliverable traces back to intent, inputs, actions, and validation |

These are requirements to implement and test, not guarantees already provided by the current runner.

## Continuity with the earlier work

`best-version-so-far/` contains active module, runner, memory, and type work. Its module specification describes frontmatter, layered configuration, installation offers, schemas, and contracts. Reuse and refine that work as the foundation becomes precise.

The current `src/core/main.sh` uses a registry and a generated home Argcfile. The module implementation uses dynamic discovery. Both belong to the ongoing work; their eventual relationship remains an explicit decision. Earlier test counts and deployment claims need revalidation before being treated as current evidence.

The bootstrap/install entry point, system definitions analogous to `/etc/skogai` and `/usr/share/skogai`, `.skogai/` as userspace or local override, typed agent work, and reusable bundles remain planned. The current Arch package installs a Bash template; packaging the eventual entry point is still open.

See [the plan](plan.md) for the next steps and [AGENTS.md](../AGENTS.md) for working instructions.
