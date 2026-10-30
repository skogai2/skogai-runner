# Declarations

Draft for review (2026-10-30). Things we keep deciding, re-asking, or spelling out inside every spec. Declare each once, point to it, stop repeating it.

Status: **settled** = already decided somewhere, just scattered. **open** = still yours to decide. **pain** = friction seen this session.

## Settled, but scattered

| Declaration | Currently lives in |
|---|---|
| Names are lowercase kebab-case, one segment; `.` and `_` are relations | memory, AGENTS.md |
| Invalid input is an answer: exit 0 with a verdict on stdout | memory, F001 spec |
| Exit 1 = a required tool is missing (checked first); exit 2 = bad arguments; stdout empty on both, diagnostic on stderr | F001 spec only |
| Machine output is compact JSONL on stdout, one object per input, in input order | F001 spec only |
| A check is a pure read: writes nothing, repeated runs are byte-identical | F001 spec only |
| Paths are relative to the declaring file's directory, compared after lexical normalisation, symlinks never resolved | F001 spec only |
| Frontmatter is state, the Markdown body is formatted text | TODO.md |
| Stack: bash + argc + yq v4 + jq, tests in bats, tools from mise at `latest` (unpinned) | context_summary |
| Tests isolate HOME under `$BATS_TEST_TMPDIR`; fixtures under `tests/fixtures/<area>/{valid,invalid/<reason>}/` | context_summary, F001 spec |
| Coverage cannot be measured for bash; `coverage` is recorded as `n/a` and `bats tests` is the gate | context_summary gotcha |
| Trust existing tools (git, mise, pacman) over building our own | memory, context_summary |
| One command per shell call | memory |
| Commit finished work without asking, own files only; harness metadata as `docs:` | memory, global CLAUDE.md |

Proposal: move the rows above into one conventions page (`docs/` or the project `CLAUDE.md`), and let specs say "follows conventions" instead of restating them. F001's spec is 4293 characters; maybe a third of that is these rows.

## Open decisions

- **Capability enforcement**: what makes the environment reject a write outside scope (bwrap, landlock, the container). Blocks plan step 2.
- **Settings ownership**: who owns what between mise, git config, environment, and module defaults. Candidate: a mise env plugin from `skogai2/mise-env-plugin-template`, so mise's own layering decides precedence.
- **New code vs the registry runner**: does contract/workorder code ever touch `src/core/main.sh`, or live beside it until a decision replaces it. `tests/main.bats` is its contract meanwhile.
- **Operation identity, retry, linked intent revisions**: unassigned (plan step 1, left out of F001).
- **Evidence**: event log location, what counts as a credential.

## Pain points seen

1. **Two sessions, two plans.** This session proposed F001-F005 and collected 19 gate answers; another session meanwhile wrote and committed a different, narrower F001 (`d7c76c7`). Half of those 19 answers are now stale. Nothing told either session about the other.
2. **Spec gate volume.** First pass: 19 questions here, 25 in the other session, then 4 passes to PASS. Most questions asked for conventions that exist but aren't written in one place.
3. **Ceremony on an empty project.** The improve loop ran with zero features; the Meta-Session retrospective is nagged every day, even on days with no feature work.
4. **Commit attribution.** Global CLAUDE.md says no `Co-Authored-By`, and it takes precedence over the session's attribution instructions. `c82a2af` carries the line anyway, a mistake; later commits leave it out.
5. **Hook noise.** Every event reports `skogai-core` hooks skipped because `cc-plugin-sec-default` runs first and passes the event on. Either intended (then silence it) or a bug.
6. **Git identity check can't pass.** The rule demands `ssh -T git@github.com` before every push/pull, but this repo is HTTPS with no key. The hook already checks name/email only; the rule text says otherwise.
7. **"Plan, then wait for go ahead" vs the proactive output style.** Both are active; it's unclear which wins for bookkeeping (features.json, retrospectives, commits).
