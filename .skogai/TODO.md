# Active plan

The earlier plans below remain active. Establish the basics first, then grow small, self-sustaining bundles. See [the vision](../docs/design.md), [the implementation sequence](../docs/plan.md), and [agent instructions](../AGENTS.md).

## Foundation first

- [ ] define concrete contracts for functional inputs/outputs, idempotent effects, immutable intent/events, strong types, and Unix interfaces
- [ ] define depends-on, reads, writes, owns, and watches through valid and invalid examples
- [ ] assign settings ownership and precedence using mise and Git config where appropriate
- [ ] hand-prepare one Markdown workorder, one command, one owned output, and an isolated environment with enforced capabilities
- [ ] verify validation before effects, safe repetition, failure behavior, and rejection of writes outside the allowed scope
- [ ] define and demonstrate append-only JSONL evidence connecting intent, messages, tools, effects, and the Git diff
- [ ] derive a reviewable delivery summary and proposed commit message at the workorder/session/PR boundary
- [ ] package the example as a self-sustaining bundle; prove reuse with a second workorder before generalizing

## Continuing plans

- [ ] quick history and background of skogai3.0
- [ ] define a list of reasons / the intentions behind what looks like yet another command runner
- [ ] go over the argc functionality and how it is used as the interface for both the user and agents
- [ ] intended packaging: a single entrypoint for init/setup/bootstrap/installation; decide its final form after the basic contracts are proven. /core/<modules> contains the core/system functionality and definitions which can be seen as the "/etc/skogai,/usr/share/skogai" and so on. lastly .skogai/ would represent the userspace, home folder or local override.
- [ ] starting point; for now the old style of {DECISIONS,PLAN,AGENTS,RULES,DEFINITIONS,CONCEPTS}.md etc can be the starting setup to prove a point and then essentially implement each concept along the way
- [ ] starting point; take the current core and break it down into its atomic parts - forcing us to split up and re-create basic things from the ground up by definitions
- [ ] the importance and intention behind the concept of frontmatter representing state and the markdown itself representing formatted text
- [ ] skogai and functional concepts in general
