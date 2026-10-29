# Design direction

This page separates the checked-out implementation from the intentions recorded in [.skogai/TODO.md](../.skogai/TODO.md) and the earlier [module design](../best-version-so-far/docs/module.md).

## Purpose

The project explores a common command interface for people and agents. argc supplies parsing, help, completion, and interface export; skogai supplies the commands and the conventions around them. The current implementation tests a small part of that idea: link command scripts into a registry and expose them through one generated entry point.

## Earlier module implementation

`best-version-so-far/` contains a fuller experiment with core, runner, memory, and type modules. A `module.md` combines structured frontmatter with prose: the frontmatter declares state and configuration, while the body explains meaning and use. The module specification describes discovery, layered configuration, installation offers, schemas, and test contracts.

Its handover records decisions such as dynamic module discovery without a registry. The current `src/core/main.sh` instead uses a registry and a generated home Argcfile. Read each design in its own context; historical test counts and deployment claims have not been revalidated by the current runner suite.

## Intended next layers

The TODO describes an eventual bootstrap/install entry point, core/system definitions analogous to `/etc/skogai` and `/usr/share/skogai`, and `.skogai/` as local user state or overrides. It also proposes starting with plain Markdown concepts and breaking the earlier core into smaller parts.

The current Arch package installs a Bash template. A single native binary, bootstrap lifecycle, and the relationship between the registry runner and module discovery remain to be defined.

## Questions to resolve

- Which behavior belongs in the common runner, and which belongs in registered commands or modules?
- How should system definitions and local overrides compose?
- Which frontmatter fields are authoritative state, and how are they validated?
- What should bootstrap install, generate, or offer for review?
- Which earlier contracts and functional conventions should become current requirements?

Use source-backed behavior for reference documentation and explicit decisions for new requirements. Keep unanswered questions visible until implementation and validation establish their answers.
