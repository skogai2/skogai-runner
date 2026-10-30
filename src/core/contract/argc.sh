#!/usr/bin/env bash
# @describe check the relationships Markdown+ files declare in their frontmatter
#
# one compact JSON verdict per file on stdout, in argument order. an invalid
# file is an answer, not a failure: exit 0 whenever every file got a verdict.
# exit 1: yq or jq missing. exit 2: no files, or one is missing, a directory,
# or unreadable. stdout stays empty on both. reads only, writes nothing.
# @meta binname contract

# shellcheck disable=SC2154 # argc_* are assigned by --argc-eval
set -euo pipefail

# @cmd check each file, and the relationships between all of them
# @arg file*                           Markdown files with frontmatter
check() {
    local tool file files=(${argc_file[@]+"${argc_file[@]}"})
    for tool in yq jq; do
        command -v "$tool" >/dev/null || { printf 'missing tool: %s\n' "$tool" >&2; return 1; }
    done
    cd "${ARGC_PWD:-$PWD}"
    ((${#files[@]})) || { printf 'usage: check <file>...\n' >&2; return 2; }
    for file in "${files[@]}"; do
        [[ -e "$file" ]] || { printf 'no such file: %s\n' "$file" >&2; return 2; }
        [[ ! -d "$file" ]] || { printf 'is a directory: %s\n' "$file" >&2; return 2; }
        [[ -r "$file" ]] || { printf 'unreadable: %s\n' "$file" >&2; return 2; }
    done
    for file in "${files[@]}"; do _frontmatter "$file"; done |
        command jq -cs --arg pwd "$PWD" "$VERDICTS"
}

# one record per file: {file, parse: <reason>|null, data: <frontmatter>|null}
_frontmatter() {
    local file="$1" lines i data
    mapfile -t lines <"$file"
    [[ ${#lines[@]} -gt 0 && "${lines[0]}" == --- ]] || { _record "$file" no-frontmatter; return; }
    for ((i = 1; i < ${#lines[@]}; i++)); do [[ "${lines[i]}" != --- ]] || break; done
    ((i < ${#lines[@]})) || { _record "$file" unterminated-frontmatter; return; }
    data="$(printf '%s\n' "${lines[@]:1:i-1}" | command yq -p yaml -o json -I0 '.' 2>/dev/null)" ||
        { _record "$file" invalid-yaml; return; }
    [[ "$(command jq -r type <<<"$data" 2>/dev/null)" == object ]] || { _record "$file" not-a-mapping; return; }
    _record "$file" "" "$data"
}

_record() {
    command jq -cn --arg file "$1" --arg parse "$2" --argjson data "${3:-null}" \
        '{file: $file, parse: (if $parse == "" then null else $parse end), data: $data}'
}

# all field and cross-file rules, over the slurped records
VERDICTS='
def norm:
  startswith("/") as $abs
  | reduce (split("/")[] | select(. != "" and . != ".")) as $s ([];
      if $s != ".." then . + [$s]
      elif length > 0 and .[-1] != ".." then .[:-1]
      elif $abs then .
      else . + [".."] end)
  | if $abs then "/" + join("/") elif length == 0 then "." else join("/") end;
def name_ok: test("^[a-z][a-z0-9-]*$");
def path_ok: type == "string" and . != "";
def outside: startswith("/") or (norm | . == ".." or startswith("../"));

def fields:
  . as $d
  | ["name", "description", "depends_on", "reads", "writes", "owns", "watches", "defaults"] as $known
  | (if ($d.depends_on | type) == "array" then [$d.depends_on[] | select(type == "string")] else [] end) as $deps
  | [["reads", "writes", "owns", "watches"][] as $k
      | if ($d | has($k)) and ($d[$k] | type) != "array" then "wrong-type"
        elif ($d | has($k)) then $d[$k][] | if path_ok | not then "wrong-type" elif outside then "path-outside-scope" else empty end
        else empty end] as $paths
  | (if ($d.owns | type) == "array" then [$d.owns[] | select(path_ok)] else [] end) as $owns
  | (if ($d.writes | type) == "array" then [$d.writes[] | select(path_ok) | norm] else [] end) as $writes
  | {
      name: ($d.name | if type == "string" then . else null end),
      deps: $deps,
      owns: $owns,
      reasons: ([
        (if ($d | keys - $known | length) > 0 then "unknown-key" else empty end),
        (if $d.name == null then "missing-name"
         elif ($d.name | type) != "string" then "wrong-type"
         elif ($d.name | name_ok | not) then "invalid-name" else empty end),
        (if ($d | has("description")) and ($d.description | type) != "string" then "wrong-type" else empty end),
        (if ($d | has("depends_on")) and ($d.depends_on | type) != "array" then "wrong-type"
         elif ($d | has("depends_on")) then $d.depends_on[] | if type != "string" then "wrong-type" elif name_ok | not then "invalid-name" else empty end
         else empty end),
        $paths[],
        (if ($d | has("defaults")) and ($d.defaults | type) != "object" then "wrong-type" else empty end),
        (if ($writes - ($owns | map(norm)) | length) > 0 then "write-not-owned" else empty end)
      ])
    };

map(. + {id: (if (.file | startswith("/")) then .file else $pwd + "/" + .file end | norm)}
    | . + {dir: (.id | split("/")[:-1] | join("/") | if . == "" then "/" else . end)}
    | if .parse == null then . + (.data | fields) else . + {name: null, reasons: [.parse]} end
    | . + {resolved: [(.owns // [])[] as $p | if ($p | startswith("/")) then $p else .dir + "/" + $p end | norm]})
| [.[] | select(.name != null)] as $named
| ($named | map(.name)) as $names
| .[]
| . as $f
| [.reasons[],
   ($f | select(.name != null)
     | (if (.deps - $names | length) > 0 then "missing-dependency" else empty end),
       (if any($named[]; .id != $f.id and .name == $f.name) then "duplicate-name" else empty end),
       (if any($named[]; .id != $f.id and any(.resolved[]; IN($f.resolved[]))) then "ownership-conflict" else empty end))]
| unique
| {file: $f.file, verdict: (if length == 0 then "valid" else "invalid" end), reasons: .}
'

eval "$(argc --argc-eval "$0" "$@")"
