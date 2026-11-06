#!/usr/bin/env -S usage bash
#USAGE bin "log"
#USAGE about "read the run event log: which runs happened, and what happened in one"
#USAGE long_about """
#USAGE reads the JSONL event log the runner appends to (docs/evidence.md). read only: it never writes anything, the log included.
#USAGE
#USAGE runs: one compact JSON object per run on stdout, in the order each run's first event appears: {run, module, revision, started, ended, outcome, verdict, changed}. started is the first event's ts. ended, outcome, verdict (input.verdict) and changed (input.changed, or []) come from the run's end event. a run without an end event (interrupted) has ended, outcome and verdict null: it is listed, not dropped.
#USAGE
#USAGE show <run>: that run's events exactly as they are in the log, one per line, in log order. <run> is a full run id or a unique prefix of one.
#USAGE
#USAGE a line that is not a JSON object, or has no string run, is skipped; stderr then says "skipped <n> unreadable lines: <file>" and the exit stays 0.
#USAGE
#USAGE exit 0: answered (an empty or missing log is an empty answer). exit 1: jq missing. exit 2: bad arguments, including show of an unknown run ("no such run: <id>"), an ambiguous prefix ("ambiguous run: <prefix>") and a log that cannot be read.
#USAGE """
#USAGE flag "--log <file>" env="SKOGAI_LOG" global=#true help="JSONL event log (default: $XDG_STATE_HOME/skogai/run.jsonl, else ~/.local/state/skogai/run.jsonl)"
#USAGE cmd "runs" effect="read" help="one JSON object per run: how each one ended" {
#USAGE }
#USAGE cmd "show" effect="read" help="the events of one run, as they are in the log" {
#USAGE   arg "<run>" help="a full run id or a unique prefix of one"
#USAGE }
#
# the same default log path as src/core/run/usage.sh (_open_log). unlike the
# runner this never creates the parent directory or the file.

# shellcheck shell=bash disable=SC2154 # usage_* are exported by usage
set -euo pipefail

# a log line that is a JSON object with a string run; jq -R feeds raw lines
READABLE='(try fromjson catch null) | select(type == "object" and (.run | type) == "string")'

# the log, or return 2 when it exists but cannot be read; sets LOG and HAVE
_open() {
    command -v jq >/dev/null || { printf 'missing tool: jq\n' >&2; return 1; }
    LOG="${usage_log:-${XDG_STATE_HOME:-${HOME:?}/.local/state}/skogai/run.jsonl}"
    HAVE=0
    [[ -e "$LOG" ]] || return 0
    [[ -f "$LOG" && -r "$LOG" ]] || { printf 'cannot read log: %s\n' "$LOG" >&2; return 2; }
    HAVE=1
}

# say how many lines were skipped, when any
_skipped() {
    local n
    n="$(command jq -Rn '[inputs | select(((try fromjson catch null) | (type == "object" and (.run | type) == "string")) | not)] | length' <"$LOG")"
    ((n == 0)) || printf 'skipped %s unreadable lines: %s\n' "$n" "$LOG" >&2
}

# every distinct run id, in first-seen order
_run_ids() {
    command jq -Rr "$READABLE | .run" <"$LOG" | command jq -Rnr '[inputs] | reduce .[] as $r ([]; if index([$r]) then . else . + [$r] end) | .[]'
}

runs() {
    _open || return $?
    ((HAVE)) || return 0
    command jq -Rnc "
      [inputs | $READABLE] as \$all
      | (\$all | reduce .[] as \$e ([]; if index([\$e.run]) then . else . + [\$e.run] end))[] as \$r
      | (\$all | map(select(.run == \$r))) as \$ev
      | (\$ev | map(select(.event == \"end\")) | last) as \$end
      | {run: \$r, module: \$ev[0].module, revision: \$ev[0].revision, started: \$ev[0].ts,
         ended: (\$end | if . then .ts else null end),
         outcome: (\$end | if . then .outcome else null end),
         verdict: (\$end | if . then .input.verdict else null end),
         changed: ((\$end | if . then .input.changed else null end) // [])}" <"$LOG"
    _skipped
}

show() {
    local id="$usage_run" ids match=() r
    _open || return $?
    if ((HAVE)); then
        ids="$(_run_ids)"
        while IFS= read -r r; do
            [[ -n "$r" ]] || continue
            [[ "$r" == "$id" ]] && { match=("$r"); break; }
            [[ "$r" == "$id"* ]] && match+=("$r")
        done <<<"$ids"
    fi
    ((${#match[@]})) || { printf 'no such run: %s\n' "$id" >&2; return 2; }
    ((${#match[@]} == 1)) || { printf 'ambiguous run: %s\n' "$id" >&2; return 2; }
    # print the raw line, not jq's re-rendering of it, so output is byte-identical
    command jq -Rr --arg run "${match[0]}" ". as \$line | $READABLE | select(.run == \$run) | \$line" <"$LOG"
    _skipped
}

case "${usage_cmd:-}" in
runs) runs ;;
show) show ;;
*) exec "$0" --help ;;
esac
