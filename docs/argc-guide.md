# argc and argc-completions

Reviewed on 2026-10-29 through the GitHub connection. Installed argc observed during the review: **1.24.0**. [mise.toml](../mise.toml) currently requests `latest`; it does not pin that version.

## Two upstream projects

| Project | Role here |
| --- | --- |
| [sigoden/argc](https://github.com/sigoden/argc) | Bash CLI parser, task runner, interface exporter, and completion engine |
| [sigoden/argc-completions](https://github.com/sigoden/argc-completions) | Completion definitions and authoring utilities for existing commands; a source of completion patterns |

The current runner invokes argc directly. It does not require the argc-completions repository to register and execute scripts. Native argc scripts already carry the tags from which argc derives their command interfaces.

## Reference revisions

- argc: [`dd0bcb484d3217c7998b717fde02e38035e67a1e`](https://github.com/sigoden/argc/tree/dd0bcb484d3217c7998b717fde02e38035e67a1e), upstream commit dated 2026-10-28.
- argc-completions: [`19b70387dc288f2018d80a99062a62d2e5965ab2`](https://github.com/sigoden/argc-completions/tree/19b70387dc288f2018d80a99062a62d2e5965ab2), upstream commit dated 2026-10-22.

These identify the source reviewed, not the provenance of the existing local copies or the revision used to build the installed argc binary.

## Read by task

- Define a CLI: [comment tags](https://github.com/sigoden/argc/blob/dd0bcb484d3217c7998b717fde02e38035e67a1e/docs/comment-tags.md), [metadata](https://github.com/sigoden/argc/blob/dd0bcb484d3217c7998b717fde02e38035e67a1e/docs/meta.md), and [variables](https://github.com/sigoden/argc/blob/dd0bcb484d3217c7998b717fde02e38035e67a1e/docs/variables.md).
- Organize recipes and working directories: [command runner](https://github.com/sigoden/argc/blob/dd0bcb484d3217c7998b717fde02e38035e67a1e/docs/command-runner.md).
- Export interfaces or generate artifacts: [argc tooling](https://github.com/sigoden/argc/blob/dd0bcb484d3217c7998b717fde02e38035e67a1e/docs/argc-tooling.md).
- Implement forwarding and dynamic choices: [completion protocol](https://github.com/sigoden/argc/blob/dd0bcb484d3217c7998b717fde02e38035e67a1e/docs/compgen.md).
- Generate definitions for existing tools: [completion generation](https://github.com/sigoden/argc-completions/blob/19b70387dc288f2018d80a99062a62d2e5965ab2/docs/generate.md) and [completion patterns](https://github.com/sigoden/argc-completions/blob/19b70387dc288f2018d80a99062a62d2e5965ab2/docs/complete-patterns.md).

## Interface shared by users and agents

`@cmd`, `@arg`, `@option`, `@flag`, and `@env` describe a command next to its Bash implementation. `eval "$(argc --argc-eval "$0" "$@")"` applies the generated parsing and dispatch code. Humans can inspect `--help`; tools can inspect `argc --argc-export <script>` as JSON. Both execute the same command implementation.

Export describes the declared interface. It does not guarantee side-effect behavior, permissions, or semantic correctness. Those properties still need implementation, documentation, and tests.

Choice functions print candidates, optionally followed by tab-separated descriptions. They may also print completion control lines. Without the `?` choice modifier, dynamic choices can validate input as well as complete it. That distinction matters for forwarding arbitrary child commands.

## Compatibility and maintenance

The copied local `specification.md` reflects an older organization than the reviewed upstream reference. Do not overwrite those snapshots piecemeal or assume current upstream examples work identically on argc 1.24.0.

Before an upgrade, record `argc --argc-version`, run `mise run test`, and inspect help, export, and delegated completion. If refreshing the upstream copies, record the import SHA, preserve license notices, and check relative links. The reviewed argc-completions revision supports bash, zsh, fish, PowerShell, and Nushell; older references may list additional shells.
