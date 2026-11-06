# Evidence: the run event log

Plan step 3: a run must be explainable from its record alone. `src/core/run/usage.sh` appends one JSONL event per step of every `check` and `run` it performs. The stdout JSON and the exit codes did not change (`tests/run.bats`).

Status: **implemented** in `src/core/run/usage.sh` only (the frozen `run/argc.sh` writes no log). **Verified** by `tests/run-events.bats`. The cases that need Podman are verified only on a host with Podman and the `skogai-runner-dev` image, and they skip anywhere else.

## Where the log goes

- `--log <file>`, or the env `SKOGAI_LOG`. Default: `$XDG_STATE_HOME/skogai/run.jsonl`, or `~/.local/state/skogai/run.jsonl` when `XDG_STATE_HOME` is unset or empty.
- The runner creates the parent directory, and it only ever opens the file for appending. Each event is written as one line.
- The log is the runner's output. It goes inside a module dir only when the caller asks for that.
- The runner checks that the log takes an append (`mkdir -p` of the parent, then an empty append) after argument checks and before anything else. When it can't append, `check` and `run` exit 1 with an empty stdout and `cannot append to log: <file>` on stderr. No contract check, container or apply has happened at that point.
- Exit 2 (bad arguments) and a missing `yq`/`jq` exit 1 happen before the log is opened, so they write nothing.

## Event shape

The envelope of the skogai-core hook log (`{ts, event, action?, input}`), extended:

| field      | value |
|------------|-------|
| `ts`       | UTC, ISO 8601 with milliseconds (`2026-11-06T15:49:54.214Z`) |
| `event`    | `check`, `exec`, `apply` or `end` |
| `action`   | present only when the event had an effect on the module dir: `applied <path>`, and on `end` `applied <path>, <path>…` |
| `input`    | the event's payload (below), with paths relative to the module dir |
| `id`       | unique per event (a random UUID) |
| `run`      | one random UUID shared by all events of one invocation |
| `module`   | the declared `name`, or `null` when it is not a valid name |
| `revision` | sha256 of the output of `sha256sum <name>.md <name>.sh` run in the module dir (the `.sh` only when it exists). Reproduce it with `(cd <dir> && sha256sum hello.md hello.sh | sha256sum)` |
| `outcome`  | `ok`, `rejected`, `failed` or `unchanged` |

Events, in order:

- `check`: `{file, verdict: valid|invalid, reasons, f001}`. Outcome `ok` or `rejected`.
- `exec` (`run` only, after a valid check): `{exit, image}`, plus `staged` (every path the command staged, sorted) and `missing` (paths in `writes` it did not stage) when the exit is 0. Outcome `ok`, or `failed` for a non-zero exit. When the command failed, its staged files are not judged and there are no `apply` events.
- `apply`, one per staged path, sorted: `{path, reason?}`.
  - `ok` + `action`: moved into place.
  - `unchanged`: the target already had identical content.
  - `failed` with reason `apply-failed`: the rename failed.
  - `rejected` with the path's own reason (`output-outside-owns`, `output-not-regular-file`), or with `not-applied` when the path was fine but the run stopped before it (another path was rejected, or an earlier apply failed).
- `end`: `input` is the stdout JSON with `module` replaced by the file name relative to the module dir. Outcome: `valid`/`applied` → `ok`, `unchanged` → `unchanged`, `invalid`/`rejected` → `rejected`. A run stopped by a missing `podman` or image writes `end` with outcome `failed` and `input` `{exit: 1, error}`, and its stdout stays empty.

A declaration rejected at check time writes `check` and `end` and nothing else.

`input` holds only what the runner decided: verdicts, reasons, paths relative to the module dir, the image name, exit codes. It holds no environment, credentials, absolute paths or module output. The module's own stderr still goes only to the runner's stderr.

## Example: a successful run, then a repeat

`run examples/usage/hello/hello.md` twice, on a copy:

```jsonl
{"ts":"2026-11-06T15:49:54.214Z","event":"check","input":{"file":"hello.md","verdict":"valid","reasons":[],"f001":[]},"id":"ce07aa4a-5ace-4744-9656-6073989ccba8","run":"24d372f9-6461-44b7-8ba6-8e73928a1c7c","module":"hello","revision":"85bddba439d0fe1807c3df106248a0669141f26601fe90d23e70037060f8ecd9","outcome":"ok"}
{"ts":"2026-11-06T15:49:54.739Z","event":"exec","input":{"exit":0,"image":"skogai-runner-dev","staged":["greeting.txt"],"missing":[]},"id":"9a726207-3831-47de-8812-c0539c1df234","run":"24d372f9-6461-44b7-8ba6-8e73928a1c7c","module":"hello","revision":"85bddba439d0fe1807c3df106248a0669141f26601fe90d23e70037060f8ecd9","outcome":"ok"}
{"ts":"2026-11-06T15:49:54.756Z","event":"apply","action":"applied greeting.txt","input":{"path":"greeting.txt"},"id":"f964ba67-0df9-4589-8589-1b748e7585a7","run":"24d372f9-6461-44b7-8ba6-8e73928a1c7c","module":"hello","revision":"85bddba439d0fe1807c3df106248a0669141f26601fe90d23e70037060f8ecd9","outcome":"ok"}
{"ts":"2026-11-06T15:49:54.774Z","event":"end","action":"applied greeting.txt","input":{"module":"hello.md","name":"hello","verdict":"applied","reasons":[],"f001":[],"changed":["greeting.txt"]},"id":"57c8419e-43e4-448a-8a55-bcda42d0731e","run":"24d372f9-6461-44b7-8ba6-8e73928a1c7c","module":"hello","revision":"85bddba439d0fe1807c3df106248a0669141f26601fe90d23e70037060f8ecd9","outcome":"ok"}
{"ts":"2026-11-06T15:49:54.950Z","event":"check","input":{"file":"hello.md","verdict":"valid","reasons":[],"f001":[]},"id":"0ae3a419-c1f9-44ab-b4dd-1207d341c4f5","run":"c763d396-5cfa-471b-b570-61810db65c39","module":"hello","revision":"85bddba439d0fe1807c3df106248a0669141f26601fe90d23e70037060f8ecd9","outcome":"ok"}
{"ts":"2026-11-06T15:49:55.430Z","event":"exec","input":{"exit":0,"image":"skogai-runner-dev","staged":["greeting.txt"],"missing":[]},"id":"73383696-8020-4ed7-b4ee-f61f979363c7","run":"c763d396-5cfa-471b-b570-61810db65c39","module":"hello","revision":"85bddba439d0fe1807c3df106248a0669141f26601fe90d23e70037060f8ecd9","outcome":"ok"}
{"ts":"2026-11-06T15:49:55.438Z","event":"apply","input":{"path":"greeting.txt"},"id":"e1fb3500-0c1e-4a5d-b11e-30dadbbd2f46","run":"c763d396-5cfa-471b-b570-61810db65c39","module":"hello","revision":"85bddba439d0fe1807c3df106248a0669141f26601fe90d23e70037060f8ecd9","outcome":"unchanged"}
{"ts":"2026-11-06T15:49:55.455Z","event":"end","input":{"module":"hello.md","name":"hello","verdict":"unchanged","reasons":[],"f001":[],"changed":[]},"id":"3ddce187-0c1c-44b4-b41a-69d1b88005eb","run":"c763d396-5cfa-471b-b570-61810db65c39","module":"hello","revision":"85bddba439d0fe1807c3df106248a0669141f26601fe90d23e70037060f8ecd9","outcome":"unchanged"}
```

## Example: a rejected run

`run` of the `outside` fixture, whose command stages `extra.txt` as well as the owned `out.txt`:

```jsonl
{"ts":"2026-11-06T15:49:55.654Z","event":"check","input":{"file":"outside.md","verdict":"valid","reasons":[],"f001":[]},"id":"8dfc29d7-af2a-4645-8492-4e7537fcbdae","run":"f040a330-fb74-4160-8ad2-8874aa4fea54","module":"outside","revision":"7b886e0a0e46fbf38d083c996b03849188131eaa3c7bd9cb9263d24d318da4fb","outcome":"ok"}
{"ts":"2026-11-06T15:49:56.164Z","event":"exec","input":{"exit":0,"image":"skogai-runner-dev","staged":["extra.txt","out.txt"],"missing":[]},"id":"545fcbfc-ec17-4df1-b677-36630b0db269","run":"f040a330-fb74-4160-8ad2-8874aa4fea54","module":"outside","revision":"7b886e0a0e46fbf38d083c996b03849188131eaa3c7bd9cb9263d24d318da4fb","outcome":"ok"}
{"ts":"2026-11-06T15:49:56.171Z","event":"apply","input":{"path":"extra.txt","reason":"output-outside-owns"},"id":"28b491b9-c1dd-4192-b671-3da51fbf04f7","run":"f040a330-fb74-4160-8ad2-8874aa4fea54","module":"outside","revision":"7b886e0a0e46fbf38d083c996b03849188131eaa3c7bd9cb9263d24d318da4fb","outcome":"rejected"}
{"ts":"2026-11-06T15:49:56.178Z","event":"apply","input":{"path":"out.txt","reason":"not-applied"},"id":"70cffda8-f437-41b3-ab98-22782d184b35","run":"f040a330-fb74-4160-8ad2-8874aa4fea54","module":"outside","revision":"7b886e0a0e46fbf38d083c996b03849188131eaa3c7bd9cb9263d24d318da4fb","outcome":"rejected"}
{"ts":"2026-11-06T15:49:56.197Z","event":"end","input":{"module":"outside.md","name":"outside","verdict":"rejected","reasons":["output-outside-owns"],"f001":[],"changed":[]},"id":"5a65cc3b-20df-4e6f-b1fd-c36c99902dbd","run":"f040a330-fb74-4160-8ad2-8874aa4fea54","module":"outside","revision":"7b886e0a0e46fbf38d083c996b03849188131eaa3c7bd9cb9263d24d318da4fb","outcome":"rejected"}
```

A declaration rejected at check time (the `badmeta` fixture) is only `check` (outcome `rejected`, `f001: ["unknown-key"]`) followed by `end`.

## Decisions taken here, not by the workorder

- Field order: the skogai-core envelope comes first (`ts, event, action?, input`), then `id, run, module, revision, outcome`.
- `revision` hashes `sha256sum`'s own output, so the `.md`/`.sh` boundary is unambiguous and anyone can reproduce the value with one shell line. When `sha256sum` is not on PATH, `revision` is `null` and stderr says so. The run doesn't stop, because `check` works with a minimal PATH (`tests/run.bats`) and that PATH has no `sha256sum`.
- `ts` and the ids come from bash alone (`EPOCHREALTIME`, `printf %()T` with `TZ=UTC0`, `/proc/sys/kernel/random/uuid`), so the log adds no tool dependency. Without `/proc`, an id is built from the time, the pid and `$RANDOM`.
- The `end` event's `input` is the stdout object with `module` relative to the module dir (stdout keeps the path as it was given).
- A staged path that was valid but never applied is logged as `rejected` with reason `not-applied`, so every staged path gets exactly one `apply`.
- A missing `podman` or image writes a `failed` `end` with `{exit: 1, error}`. The workorder only specified `end` for verdicts.
- The runner logs `end` before it prints stdout. When the append fails at that point, the exit is 1 and stdout stays empty.

## Open (planned, not built)

- **Append failure after an effect.** When an `apply` or `end` append fails after a file was already moved into place, the runner stops with exit 1. The effect stays, and the log lacks its record. Recovering from this, or from an interrupted write that leaves a partial last line, is not handled.
- **Rotation and size.** The log only grows.
- **Concurrency.** Each event is one `printf` to an `O_APPEND` file, which in practice keeps lines from interleaving on a local filesystem for lines this short. Nothing locks the file, and nobody has tested concurrent runs.
- **Reader or summary command.** There is none yet. `jq 'select(.run == "<id>")' run.jsonl` is the reader.
- **Workorder link.** Events do not name a workorder, a session or a commit. Linking intent → run → Git diff is the next step of plan step 3.
- **Messages and tool use.** Only the runner's own steps are recorded. Agent messages and tool calls are not.
- **Tests and the real log.** Fixed at merge (2026-11-06): `tests/run.bats` and `tests/examples.bats` now set `XDG_STATE_HOME` under the test dir and unset `SKOGAI_LOG`, as `tests/run-events.bats` does. Any new test that calls the runner must do the same.
