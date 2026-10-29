- @.skogai/TODO.md contains one-line descriptions of tasks to be done
- !`wt step diff -- --cached > .skogai/tmp/wt-git-diff-cached` generates the file @.skogai/tmp/wt-git-diff-cached to show the users staged changes. see this as "proposed changes" or that it should actively be considered together with the users message.

## Harness

This project uses the Long-Running Agent Harness (vv-harness plugin).

- Feature tracking: `.harness/features.json`
- Context and decisions: `.harness/context_summary.md` (READ THIS at session start)
- Progress handoff: `.harness/claude-progress.txt`
- Build/test: `.harness/init.sh` (bash + argc, bats via mise)
- Quality gates: `.claude/hooks/` (TaskCompleted, scope, git identity, commit gate)

## Git Identity

Emil Skogsund <emil@skogsund.se>, HTTPS remote `github.com/skogai2/skogai-runner` (no SSH key).
