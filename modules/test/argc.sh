#!/usr/bin/env bash
# @describe run modules' tests with bats, what they require first
#
# a module is tested after everything it requires, and only if that passed:
# testing config tests core first. each module runs core's
# tests/contract.bats, the tests/contract.bats of each module it requires,
# then its own tests/*.bats. every test loads helper.bash for an empty sandbox.
# tests and contracts come from the source when there is one, else where it is found.
# @meta require-tools bats,yq
# @meta binname skogai test

# shellcheck disable=SC2154 # argc_* are assigned by --argc-eval, SKOGAI_* by `skogai module env`
set -euo pipefail

: "${SKOGAI_MODULE_DIR:?run me as \`skogai test\`}"

# @cmd run the tests of modules and of what they require, in the order of closure
# @arg module*[`_choice_module`]  default every module found
# @flag --only  just the named modules, not what they require
# @option --filter  only tests whose name matches this regex
run() {
    local name dir r core rc=0 files order
    local -A failed=()
    if [[ ${argc_only:-} == 1 ]]; then
        order=("${argc_module[@]}")
        [[ ${#order[@]} -gt 0 ]] || mapfile -t order < <(_choice_module)
    else
        mapfile -t order < <(_closure "${argc_module[@]}")
    fi
    core="$(_dir core)"
    for name in "${order[@]}"; do
        dir="$(_dir "$name")" || { echo "no module: $name" >&2; failed[$name]=1; rc=1; continue; }
        files=("$core/tests/contract.bats")
        while IFS= read -r r; do
            [[ -n $r ]] || continue
            if [[ -n ${failed[$r]:-} ]]; then
                echo "# $name: skipped, $r failed" >&2
                failed[$name]=1 rc=1
                continue 2
            fi
            [[ $r == core ]] || [[ ! -f $(_dir "$r")/tests/contract.bats ]] || files+=("$(_dir "$r")/tests/contract.bats")
        done < <(_requires "$dir")
        [[ ! -d $dir/tests ]] || mapfile -t -O "${#files[@]}" files < <(find "$dir/tests" -name '*.bats' ! -path "$dir/tests/contract.bats" | sort)
        echo "# $name" >&2
        # the module under test is a source in its isolated repo, wherever it was found
        SKOGAI_MODULE_PATH="$(dirname "$dir"):$SKOGAI_MODULE_PATH" \
            SKOGAI_TEST_MODULE="$name" SKOGAI_TEST_HELPER="$SKOGAI_MODULE_DIR/helper.bash" \
            bats ${argc_filter:+--filter "$argc_filter"} "${files[@]}" || { failed[$name]=1 rc=1; }
    done
    return "$rc"
}

# @cmd the order run tests in: what each module requires, then the module, each once
# @arg module*[`_choice_module`]  default every module found
closure() {
    _closure "${argc_module[@]}"
}

# names in dependency order, depth first; a cycle is cut where it closes
_closure() {
    local -A seen=()
    local names=("$@") n
    [[ ${#names[@]} -gt 0 ]] || mapfile -t names < <(_choice_module)
    _visit() {
        local dir r
        [[ -z ${seen[$1]:-} ]] || return 0
        seen[$1]=1
        if dir="$(_dir "$1")"; then
            while IFS= read -r r; do [[ -z $r ]] || _visit "$r"; done < <(_requires "$dir")
        fi
        echo "$1"
    }
    for n in "${names[@]}"; do _visit "$n"; done
}

# a module's dir: its source, else where it is found
_dir() {
    "$SKOGAI_BIN" module source "$1" 2>/dev/null ||
        "$SKOGAI_BIN" module show "$1" 2>/dev/null | awk -F"\t" "NR == 1 && \$2 != \"\" { print \$2; f = 1 } END { exit !f }"
}

_requires() { yq --front-matter=extract '.requires[]' "$1/module.md" 2>/dev/null || true; }

_choice_module() { "$SKOGAI_BIN" module ls | cut -d' ' -f1; }

eval "$(argc --argc-eval "$0" "$@")"
