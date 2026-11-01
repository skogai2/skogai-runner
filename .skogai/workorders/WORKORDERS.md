---
title: workorders
type: routing
permalink: skogai-runner/workorders
---

# Workorders

This folder is where to go next. The lead session (the orchestrator) keeps a queue of small, self-contained jobs. Each job goes to another agent, which implements it on its own branch and opens a draft PR. The lead keeps the plan and reviews the results. The agents only see what their workorder gives them.

These are hand-prepared workorders, not the [step 2 lifecycle](../../docs/plan.md). Nothing in this folder enforces capabilities or records evidence yet.

## Routes

- `open/*.md`: ready to hand out. Every file in this folder can run in parallel with the others.
- `done/*.md`: finished. The lead moves a workorder here in the same change that lands its PR.
- Waiting on skogix: the step 2 workorder from the plan (one module, one command, one owned output, enforced writable scope). It is blocked on how the environment will reject writes outside the allowed scope (see `.harness/claude-progress.txt`, session 3).

## A workorder

A Markdown+ file. The frontmatter is what the [contract checker](../../src/core/contract/argc.sh) can verify. The body is the instruction.

- `name`: lowercase, one segment, unique. Also the branch and PR title suffix.
- `owns`: the only paths the agent may create or change, relative to the repo root. Two open workorders must never own the same path. That is what makes handing them out in parallel safe.
- `reads`: what the agent should read first. It may read anything, but this is the context it needs.
- Body sections: **Intent** (why), **Deliverable** (what exists when done), **Acceptance** (commands that must pass), **Out of scope**, **Report back**.

Keep each one finishable in a single session with a diff that someone can review in one sitting. When a workorder grows past that, split it.

## Orchestrating

Before handing anything out, check the queue. Every line must be `"verdict":"valid"`:

```bash
mise exec -- argc --argc-run src/core/contract/argc.sh check .skogai/workorders/open/*.md
```

Hand a workorder to an agent with this prompt, filling in `<name>`:

> Implement the workorder `.skogai/workorders/open/<name>.md` in skogai-runner. Read it and its `reads` first, along with `CLAUDE.md`. Create or change only the paths listed under `owns`. If the work needs anything else, stop and say so instead of widening the change. Run every Acceptance command. Commit on a branch named `wo/<name>`, open a draft PR titled `wo/<name>: <description>`, and reply with what changed, the acceptance output, and anything left undone.

Review the PR against Acceptance and check that the diff touches nothing outside `owns`. Then merge it and move the file to `done/`. The lead updates the bookkeeping: `.harness/*`, `docs/plan.md` status, and this file.

## Open decisions

These came up while writing this queue. They are recorded here, not settled.

- **Path base.** The checker resolves `owns` relative to the declaring file's own directory, and rejects `..` and absolute paths. Workorders mean repo-root-relative paths. Conflict detection is still correct because every open workorder sits in the same folder. The `path-outside-scope` rule does not mark the repo boundary for these files.
- **`depends_on` after completion.** A dependency that moves to `done/` drops out of a check over `open/` and shows up as `missing-dependency`. Checking `done/` as well would make finished workorders' `owns` conflict with new ones. Until this is decided, open workorders are independent and don't use `depends_on`.
- **Enforcement.** `owns` is declared, not enforced. Review is the only guard until step 2 decides on a mechanism.
