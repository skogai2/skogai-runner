# Documentation

Start with the [project README](../README.md) for setup, then [runner.md](runner.md) for the current implementation.

| Document | Purpose |
| --- | --- |
| [Runner](runner.md) | Registry, generated commands, paths, completion, and failure behavior |
| [argc guide](argc-guide.md) | Upstream roles, reference links, source revisions, and local compatibility |
| [Design direction](design.md) | Active vision, foundational guarantees, and workorder lifecycle |
| [Plan](plan.md) | Concrete sequence from contracts to reusable bundles |
| [Agent instructions](../AGENTS.md) | Principles and working rules for this repository |
| [Active module specification](../best-version-so-far/docs/module.md) | Existing design for modules, configuration, manifests, and contracts |
| [Earlier handover](../best-version-so-far/HANDOVER.md) | Module decisions and earlier validation claims to recheck before reuse |

## Local upstream references

`argc/` and `argc-completions/` contain previously copied upstream references and examples. Their import revisions were not recorded. Treat them as historical snapshots, and consult the pinned upstream links in the [argc guide](argc-guide.md) before relying on version-sensitive behavior. The additional copies under `best-version-so-far/modules/core/docs/argc/` belong to the earlier module implementation.

Project documentation describes behavior in the checked-out source. Upstream documentation describes its recorded revision, which may differ from the installed tool. Keep observed behavior, design intent, and historical claims distinct when updating these pages.
