# skogai-runner

Get the absolute basics dependable, then build small, self-sustaining modules. The old plans are still active. We are putting their foundation in place first.

Read [the vision](docs/design.md), [the plan](docs/plan.md), and [the current runner](docs/runner.md). [.skogai/TODO.md](.skogai/TODO.md) and [best-version-so-far/TODO.md](best-version-so-far/TODO.md) retain the wider backlog.

## The pieces

- **argc** is the interface and runtime validation. Use its declarations for parsing, help, completion, man pages, and JSON export. Derive tool declarations and REPL tooling from that interface where possible; verify what argc supplies before adding an adapter.
- **mise** provides the development environment, dependencies, and development tasks. Use it with Git config where they fit configuration and key/value settings. Give each setting a clear owner and precedence.
- **Markdown+** makes intent and relationships programmable. A module starts as a Markdown file: prose describes intent; typed frontmatter declares dependencies, ownership, reads, writes, watches, and defaults. Add behavior as those declarations acquire precise meanings.

## How to build

- Keep it primitive and concrete. Prefer files, standard streams, exit codes, Git, and existing tools. Add a service, socket, or bus when a demonstrated requirement needs it.
- Use small functions and tools with explicit inputs and outputs. Keep decisions separate from effects. Put machine-readable results on stdout and diagnostics on stderr.
- Make effects idempotent: repeating the same operation must not duplicate its effects. Define operation identity and retry behavior before automating retries.
- Keep accepted intent and recorded events immutable. A revision creates a linked record. Configuration and generated views may change under an explicit contract.
- Validate types and relationships before effects. Reject invalid, ambiguous, or unsupported declarations clearly. Do not silently invent defaults or treat missing input as success.
- Establish ownership before writing a file or resource. Use isolated paths and atomic replacement where appropriate. Specify partial-failure behavior for external effects that cannot be rolled back.
- Make prohibited actions unavailable through filesystem access, credentials, and exposed tools. Frontmatter and prose alone do not enforce permissions. Give the agent freedom within the capabilities prepared for its workorder.
- Preserve unrelated work. Review the diff and run checks appropriate to the change. For runner behavior, use `mise run test`; isolate tests from real user configuration.

## Workorders and evidence

A workorder prepares the work: user intent, relevant context and files, typed inputs and deliverables, dependencies, capabilities, writable scope, and acceptance checks. Present its environment and tools at session start. Hand-prepare one complete example before generalizing its schema.

The target is an append-only JSONL event record connecting messages, tool use, outcomes, and file changes to the workorder. Git supplies the diff; observations and external effects need their own evidence. At a workorder, session, or PR boundary, use that evidence to explain the result and prepare a commit connecting change to intent. Commit and publish according to the task's authorization.

This lifecycle is a goal, not an implemented guarantee. Until tooling enforces it, keep a reviewable diff and a clear account of intent, changes, checks, and unresolved effects. Do not claim validation or an event trail that was not recorded.

## Continuity

The current packaged implementation is `src/core/main.sh`. `best-version-so-far/` contains active design and reusable implementation work; it is not superseded. Revalidate behavior and old test claims before reuse. Change it when the task calls for it, without assuming every earlier implementation choice is settled.

Extend existing concepts before introducing another framework. When a contract is unclear, write the smallest concrete example and record the unresolved decision. Distinguish intended, implemented, and verified behavior in documentation.
