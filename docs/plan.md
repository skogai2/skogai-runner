# Plan

The earlier plans are active. This sequence puts their foundation first; it does not replace the wider backlog in [.skogai/TODO.md](../.skogai/TODO.md) and [best-version-so-far/TODO.md](../best-version-so-far/TODO.md).

## 1. Establish the contracts

- Define the concrete meanings of depends on, reads, writes, owns, and watches. Keep frontmatter field names provisional until one example works.
- Define required inputs, typed outputs, exit behavior, and validation before effects.
- Define operation identity, retry behavior, and linked intent revisions.
- Assign configuration ownership and precedence across mise, Git config, environment, and module defaults. Demonstrate a gap before building another settings engine.

Done when valid and invalid examples have unambiguous outcomes, including missing dependencies, conflicting ownership, and writes outside the allowed scope.

## 2. Hand-prepare one complete workorder

Use one Markdown module, one declared local command, and one owned output in an isolated directory. Prepare intent, context, dependencies, tools, access, and acceptance checks before the agent starts. Use argc for the interface and mise for the development environment.

Start with explicit commands and one writer. No daemon or network service is needed for this example.

Done when the workorder can be validated, inspected, executed, repeated without duplicate effects, and checked without touching real user configuration. Rejected declarations leave the output unchanged. The environment rejects a write outside the allowed scope; declaring the restriction alone is insufficient.

## 3. Connect evidence to the result

Define a minimal JSONL event structure: event identity, workorder identity and revision, kind, relevant input or action, outcome, and artifact references. Record messages, tool use, failures, and changes. Keep credentials out of recorded payloads.

Keep accepted intent immutable and events append-only; derive summaries from them. Specify recovery after interrupted writes and operations, including the gap between an external effect and recording its outcome. Never retry an uncertain effect blindly.

Done when failed and successful runs can be explained from their records, retries do not duplicate effects, and a reviewable diff and proposed commit message connect result to intent. Git does not provide rollback for external effects.

## 4. Package and reuse

Package the demonstrated intent, declarations, command, dependencies, checks, and documentation into a small, self-sustaining bundle. Reuse suitable parts of the active module work. Prepare a second workorder before extracting more general machinery.

Done when both examples can be prepared from declared inputs, run in isolation, and checked against the same contracts. The developer's machine must not accidentally supply undeclared dependencies.

## 5. Grow from demonstrated needs

Continue the existing module, memory, type, runner, bootstrap, and installation plans. Add publish/subscribe behavior when concrete capabilities need it. Establish delivery and recovery semantics with file-backed records before deciding whether a service or another transport earns its complexity.

## Current status

The vision and instructions are documented. The registry runner and its Bats suite exist. The relationship contract checker (`src/core/contract/argc.sh`, step 1 relationships only) is implemented and tested. The workorder lifecycle, event log, and capability enforcement remain planned. The next implementation task is the local workorder in step 2.
