#!/usr/bin/env -S usage bash
#USAGE bin "contract"
#USAGE about "check the relationships Markdown+ files declare in their frontmatter"
#USAGE long_about """
#USAGE one compact JSON verdict per file on stdout, in argument order. an invalid file is an answer, not a failure: exit 0 whenever every file got a verdict.
#USAGE
#USAGE exit 1: yq or jq missing, or yq is not mikefarah's yq v4 or newer (another program named yq would turn every file into invalid-yaml).
#USAGE
#USAGE exit 2: no files, or one is missing, a directory, or unreadable. stdout stays empty on both. reads only, writes nothing.
#USAGE """
#USAGE cmd "check" help="check each file, and the relationships between all of them" {
#USAGE   arg "[file]..." help="Markdown files with frontmatter" var=#true
#USAGE }
#
# the usage twin of argc.sh: same rules, same output, same exit codes. usage
# parses the comments above and exports usage_cmd and usage_file; argc.sh gets
# argc_* from --argc-eval instead. usage itself exits 1 when the command line
# does not fit the spec, and 181 when the spec is broken.

# shellcheck shell=bash disable=SC2154 # usage_* are exported by usage
set -euo pipefail

check() {
    local tool file version files=()
    # a variadic arg arrives as one shell-quoted string, not an array
    eval "files=(${usage_file:-})"
    for tool in yq jq; do
        command -v "$tool" >/dev/null || { printf 'missing tool: %s\n' "$tool" >&2; return 1; }
    done
    # mikefarah's yq v4+ prints "yq (https://github.com/mikefarah/yq/) version v4.x.y";
    # the python wrapper prints "yq 3.x" and mikefarah's v3 "yq version 3.x"
    version="$(command yq --version 2>&1)" || true
    version="${version%%$'\n'*}"
    [[ "$version" =~ ^yq\ \(https://github\.com/mikefarah/yq/?\)\ version\ v?([0-9]+)\. ]] &&
        ((BASH_REMATCH[1] >= 4)) ||
        { printf 'wrong yq: need mikefarah/yq v4 or newer, found: %s\n' "$version" >&2; return 1; }
    # usage runs the script where it was called, so no cd back to the caller
    ((${#files[@]})) || { printf 'usage: check <file>...\n' >&2; return 2; }
    for file in "${files[@]}"; do
        [[ -e "$file" ]] || { printf 'no such file: %s\n' "$file" >&2; return 2; }
        [[ ! -d "$file" ]] || { printf 'is a directory: %s\n' "$file" >&2; return 2; }
        [[ -r "$file" ]] || { printf 'unreadable: %s\n' "$file" >&2; return 2; }
    done
    # a module is a mise config file: a case-sensitive .toml suffix with a stem
    for file in "${files[@]}"; do
        if [[ "${file##*/}" == ?*.toml ]]; then _toml "$file"; else _frontmatter "$file"; fi
    done | command jq -cs --arg pwd "$PWD" "$VERDICTS"
}

# one record per module file: kind toml; parse stage stops with exactly one reason.
# data is the relationship table _.skogai.<name>, module what the module rules need
_toml() {
    local file="$1" base="${1##*/}" doc
    doc="$(command yq -p toml -o json -I0 '.' "$file" 2>/dev/null)" || {
        command jq -cn --arg file "$file" '{file: $file, kind: "toml", parse: "invalid-toml", data: null, module: null}'
        return
    }
    command jq -cn --arg file "$file" --arg stem "${base%.toml}" --argjson doc "$doc" '
        ($doc | if type == "object" then ._ else null end) as $u
        | ($u | if type == "object" then .skogai else null end) as $s
        | ($s | if type == "object" then keys else [] end) as $k
        | {file: $file, kind: "toml",
           parse: (if ($s | type) != "object" or ($k | length) == 0 then "no-declaration"
                   elif ($k | length) > 1 then "multiple-declarations"
                   elif ($s[$k[0]] | type) != "object" then "not-a-mapping"
                   else null end)}
        | . + (if .parse != null then {data: null, module: null}
               else {data: $s[$k[0]],
                     module: {stem: $stem, key: $k[0], top: ($doc | keys), under: ($u | keys),
                              hasenv: ($doc | has("env")), env: $doc.env, tasks: $doc.tasks}} end)'
}

# one record per file: {file, kind, parse: <reason>|null, data: <frontmatter>|null}
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
        '{file: $file, kind: "md", parse: (if $parse == "" then null else $parse end), data: $data, module: null}'
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

# $key: the module name for a toml record (the table key), else null.
# in a module the name is the key and defaults are [env], so both are unknown there
def fields($key):
  . as $d0
  | (if $key == null then . else del(.name, .defaults) + {name: $key} end) as $d
  | (if $key == null then ["name", "description", "depends_on", "reads", "writes", "owns", "watches", "defaults"]
     else ["description", "depends_on", "reads", "writes", "owns", "watches"] end) as $known
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
        (if ($d0 | keys - $known | length) > 0 then "unknown-key" else empty end),
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

# the module-only rules, over a toml record that parsed
def module_reasons:
  .module as $m
  | .name as $n
  | ("SKOGAI_" + ($n | ascii_upcase | gsub("-"; "")) + "_") as $pre
  | ($m.tasks | if type == "object" then . else {} end) as $tasks
  | [
      (if ($m.top - ["_", "env", "tasks"] | length) > 0 or ($m.under - ["skogai"] | length) > 0 then "unknown-section" else empty end),
      (if $n != $m.stem then "name-mismatch" else empty end),
      (if $m.hasenv and ($m.env | type) != "object" then "wrong-type"
       elif $m.hasenv and any($m.env | keys[]; . != "_" and ((startswith($pre) | not) or length <= ($pre | length))) then "env-outside-prefix"
       else empty end),
      (if ($tasks[$n] | type) != "object" or ($tasks[$n].usage | type) != "string"
          or (($tasks[$n].run | type) != "string" and (($tasks[$n].run | type) != "array" or any($tasks[$n].run[]; type != "string")))
       then "missing-task" else empty end),
      (if any($tasks | keys[]; . != $n and ((startswith($n + ":") and (.[($n | length) + 1:] | test("^[a-z][a-z0-9-]*$"))) | not))
       then "task-outside-prefix" else empty end)
    ];

map(. + {id: (if (.file | startswith("/")) then .file else $pwd + "/" + .file end | norm)}
    | . + {dir: (.id | split("/")[:-1] | join("/") | if . == "" then "/" else . end)}
    | if .parse == null then .module.key as $k | . + (.data | fields($k)) else . + {name: null, reasons: [.parse]} end
    | if .kind == "toml" and .parse == null then .reasons += module_reasons else . end
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

# usage hands over the chosen subcommand instead of calling a function for it
case "${usage_cmd:-}" in
check) check ;;
*) exec "$0" --help ;;
esac
