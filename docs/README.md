# Documentation

Start with [AGENTS.md](../AGENTS.md) for setup, commands and working rules.

| Document | Purpose |
| --- | --- |
| [Why](why.md) | The problem, why a command runner, and the principles behind it |
| [History](history.md) | How skogai 3.0 came to be and where it is going |
| [Markdown+](markdown-plus.md) | Frontmatter as state, body as text, and the relationships it declares |
| [argc guide](argc-guide.md) | The retired argc interface: upstream roles, reference links, source revisions |
| [Design direction](design.md) | Active vision, foundational guarantees, and workorder lifecycle |
| [Plan](plan.md) | Concrete sequence from contracts to reusable bundles |
| [Agent instructions](../AGENTS.md) | Principles and working rules for this repository |
| [Active module specification](../best-argc-version/docs/module.md) | Existing design for modules, configuration, manifests, and contracts |
| [Earlier handover](../best-argc-version/HANDOVER.md) | Module decisions and earlier validation claims to recheck before reuse |

## Local upstream references

`argc/` and `argc-completions/` contain previously copied upstream references and examples. Their import revisions were not recorded. argc is retired (2026-11-06); treat them as historical snapshots. The additional copies under `best-argc-version/modules/core/docs/argc/` belong to the earlier module implementation.

Project documentation describes behavior in the checked-out source. Upstream documentation describes its recorded revision, which may differ from the installed tool. Keep observed behavior, design intent, and historical claims distinct when updating these pages.
