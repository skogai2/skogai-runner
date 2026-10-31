# History

How skogai 3.0 came to be, for agents picking up the work. It records the shifts in thinking, not the code that carried them.

## Where it started

SkogAI began as a personal ecosystem for managing a workstation with agents. It grew from there into tooling for building agents and handing work to them. Each generation answered the same question better: how does an agent get exactly the context and capabilities it needs, and nothing else?

## The stages

### Bridging tools to agents

The first approach exposed existing scripts to agents through a bridge: a script became a tool an agent could call. It worked, but each integration needed its own glue, and the tools an agent saw could drift from the commands a human used.

**Lesson:** a separate agent interface diverges. The interface should be shared.

### One registry of commands

Next, commands were registered once and exposed through a single entrypoint, each with its own help, argument parsing and completion. Humans and agents used the same commands.

**Lesson:** a shared, declared interface works. But a command alone does not say what it reads, what it writes, what it depends on, or why it exists.

### Modules

Commands grew into modules: a command packaged with the files it works with, its configuration defaults, its dependencies and a description of what it is for. Modules were found at run time across layers (local, user, system) and offered to a project rather than installed over it. Typed agent work, memory and schemas were built as modules.

**Lesson:** the shape was right, but a lot was built on contracts that had never been pinned down. Earlier claims of what worked could not all be reproduced, and every new piece re-argued the same basics.

### Foundation first: skogai 3.0

skogai 3.0 is a deliberate step back. The module plans remain active, nothing is abandoned, but the basics come first:

- what it means to depend on, read, write, own and watch something
- what a valid declaration is, and what an invalid one answers
- what repeating an operation does
- how intent and events are recorded and never rewritten
- how the environment, not instructions, limits what work can touch

Peripheral modules were set aside on purpose so the core gets the focus. The first concrete step was checking declared relationships: given a set of declarations, answer for each one whether it is valid and why not.

## Where it is going

1. **Contracts.** Unambiguous answers for valid and invalid declarations.
2. **One prepared workorder.** One piece of intent, one command and one owned output, in an isolated environment that enforces its scope. Prepared by hand before preparation is automated.
3. **Evidence.** An append-only record connecting intent, messages, actions and changes, so every result can be explained and turned into a reviewable change with a message describing its intent.
4. **Bundles.** The working example packaged as a small, self-sustaining unit, then proven by reusing it for a second workorder before anything is generalised.
5. **Growth.** Modules, memory, types, bootstrap and installation rebuilt on those contracts. Richer communication (publish/subscribe, services) arrives only when a demonstrated need justifies it.

## The constant

Through every stage, the aim has stayed the same: agents write their own context, manage their own work, and improve the system they run in. Each stage made that more precise. skogai 3.0 makes it dependable.

See [why](why.md) for the principles and [Markdown+](markdown-plus.md) for how intent is declared.
