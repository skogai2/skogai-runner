- [ ] types as modules: a module (e.g. gita) declares the files it owns or relates to (tools/gita.md, bin/gita, scripts/gita/*)
  - okn `typed_links` cannot express this: link targets must be declared document types, so `bin/gita` is not a valid target
  - okf `resource` takes only one path
  - candidate: `skogai_schema` key such as `owns: [paths]`, checked by skogai after `okn validate`
- [ ] knowledge vs memory: split on lifetime using okf `status` / `stale_after`?
- [ ] task: rename to workorder? "task" collides with mise and claude code
- [ ] spec: overlaps with type and rule. proposal / design, or drop?
- [ ] tool: `docs/tools/<name>.md` folded into `type/tool/<name>.md`, and `workflow/` made `workflows/`. confirm
- [ ] rule: defines its own "watched file" field, so `<watched-file>` is explained one step away (by the rule type itself)
- [ ] trigger: split `when` into a defined `event` field (paths belong to rule/watches). what is an event, and where does it come from?
- [ ] skogai cli: where does a dot record its dash ref?
- [ ] skogai cli: merge semantics per field when folding layers. config is replace-only for now; append for multi-valued keys?
- [ ] config: should `dash.ref` live in the local config?
- [ ] config: strict keys declared by types, or free-form?
- [ ] config/env: namespace control vars. `SKOGAI_GLOBAL_CONFIG` collides with key `global.config`. candidate: reserve the `config` section, so layer paths are keys `config.global` / `config.local` -> `SKOGAI_CONFIG_GLOBAL` / `SKOGAI_CONFIG_LOCAL`, and refuse to set them from a file layer
- [ ] schema: `fields` is a map of key -> value, not a list of names. required for every instance: `type`, `title`, `owns` (every instance has a living space: tool/gh lives under type/tool, type/tool under the base type). maybe `created` / `edited`. allow the okf base instead of `additionalProperties: false`
- [ ] relations are one step: gh is tool/gh, tool is type/tool, repo skogai is gh/skogai. sharing is several direct relations (tool/gh, cli/gh, git/gh), never a chain. every `<variable>` in a path is defined by the instance itself or its parent
- [ ] skogai cli: how does a type declare that a file is derived, and by what function?
- [ ] agent prompts: the cli has only `config` so far (`argc config`). until it has `check`, `plan` and `apply`, an agent runs `check`, `plan` and `apply` from `workflows/skogai.md` (owned by tool skogai). init elsewhere is `apply` on an empty dot. `check` is written and runs as `mise run dash:check [dot]`; `plan` and `apply` wait on the open cli items above
- [ ] router: decision 0006 keeps routing out of dash until the type layer works. `type/router.md` is a draft folded from `tmp/routing/`. keep it as a draft, or move it back to tmp?
- [ ] router: "frontmatter `type` names the root xml block" (router -> `<routes>`). make it the rule for every type, or keep it router-only?
- [ ] router: permalink `repo/file` resolves to `~/repo`, `~/.local/src/repo` or `projects/repo`. replaced by "refs resolve to commits", or does it belong in repo?
- [ ] tmp/routing schemas: `lesson` (match.keywords, rule/context/pattern) vs knowledge/memory, `workflow` (objective/steps/validation) vs `workflows/<name>.md`, `template`, `reference`. map to types or drop
- [ ] tmp/routing scripts: validators overlap okn and `check` ("don't rebuild okn"). port the router check into `check`, or drop
- [ ] tmp/routing references: `at-linking.md` and `dynamic-output-blocks.md` are claude code knowledge, not dash. move to knowledge, or to marketplace?
- [ ] graph: `README.md` is derived (`mise run dash:graph`) but has no owner. which type writes it, `type` or `router`? and should `check` regenerate and compare it, like `DECISIONS.md`?
- [ ] skogai-config: port get/set/list/env/unset from `git config -f` to mise toml layers. see [status](bin/skogai-config.md#status)

# OLD IMPLEMENTATION TODOS! ONLY CHECK IF NEEDED HERE OR DISMISS!

These plans remain active. [The foundation-first plan](../docs/plan.md) establishes the contracts before expanding this implementation. Revalidate older assumptions and deployment-specific tasks against the current environment.

- [ ] runner;`evals/`: cases that check an agent reaches for `skogai runner send`/`wo` instead of doing the work inline, run with `skogai marketplace evals skogai-runner`
- [ ] runner;workers with `--tools` run in the caller's tree. `wo run --sandbox` gives them their own cwd and skogai config, not a copy of the tree: give tool-using workers that edit this repo a `wt` worktree (`wo run --worktree`), see projects/orchestration delegate
- [ ] runner;`wo` results are untyped files beside the workorder. decide if workorder becomes a dash type (dash TODO: task -> workorder)
- [ ] runner;fold `mise run dash:check` into `skogai` or keep mise for tasks and skogai for agent io. pick one runner
- [ ] runner;port what is still useful from old-core (`~/old/old-core/Argcfile.sh`: repo, queue, tools) into modules
- [ ] marketplace;fold `scripts/` and the pre-commit checks into the marketplace module
- [ ] module;plugins other than skogai-runner shipping `modules/`: how they get onto `SKOGAI_MODULE_PATH`
- [ ] module;`module update`: pull source changes into an installed copy, `keep` respected
- [ ] module;top-level `bin/` blocks claude.ai organization sync of this plugin (docs/plugins/components.md)
- [ ] module;`~/.local/src/argc-completions/completions/skogai.sh` is generated from the gone dash-skogai CLI and shadows `skogai` completion
- [ ] module;`~/skogai/.skogai/config` is a directory, the local config layer is a file at that path
- [ ] module;`~/skogai` memory `dotfiles-via-mise-tools` has no `stale_after`
- [ ] module;`plugins/skogai-core/CONFIG.md` describes `~/skogai/dash-skogai/bin/skogai`, which no longer exists
- [ ] module;installed copies in `~/.config/skogai/modules/` (core, memory, runner, testname) shadow the sources and are behind them; `testname` has no source
