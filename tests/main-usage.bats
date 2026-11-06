#!/usr/bin/env bats
# src/core/main-usage.sh: the usage twin of main.sh. no template, no sync and
# no generated main: registered scripts reach usage through a mount

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    export SKOGAI_COMMANDS="$HOME/.config/skogai/commands"
    export SKOGAI_MAIN="$BATS_TEST_DIRNAME/../src/core/main-usage.sh"
    work="$BATS_TEST_TMPDIR/work"
    mkdir -p "$HOME/sub" "$work"
    cat >"$work/hello.sh" <<'EOF'
#!/usr/bin/env -S usage bash
#USAGE about "greets people"
#USAGE long_about """
#USAGE second line of the description
#USAGE """
#USAGE cmd "greet" help="say hi" {
#USAGE   arg "[who]" { choices "alice" "bob" }
#USAGE }
#USAGE cmd "where" help="print cwd"
set -euo pipefail
case "${usage_cmd:-}" in
greet) echo "hi ${usage_who:-}" ;;
where) pwd ;;
esac
EOF
    printf '#!/usr/bin/env -S usage bash\n#USAGE cmd "broken" {\n#USAGE   arg "<x>\n#USAGE }\n:\n' >"$work/broken.sh"
    printf '#!/usr/bin/env bash\necho plain\n' >"$work/plain.sh"
}

main() { "$SKOGAI_MAIN" "$@"; }
complete() { usage complete-word --shell bash -f "$SKOGAI_MAIN" -- skogai "$@"; }

@test "an empty registry still gives a main that runs" {
    run main --help
    [ "$status" -eq 0 ]
    [[ "$output" == *register* && "$output" == *ls* ]]
    run main ls
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "register links the file and the command runs at once, with no sync" {
    run main register "$work/hello.sh" hello
    [ "$status" -eq 0 ]
    [ "$(readlink "$SKOGAI_COMMANDS/hello.sh")" = "$work/hello.sh" ]
    run main hello greet bob
    [ "$status" -eq 0 ]
    [ "$output" = "hi bob" ]
}

@test "nothing is generated: the registry holds only symlinks" {
    main register "$work/hello.sh" hello
    [ "$(find "$HOME" -type f | wc -l)" -eq 0 ]
    [ "$(find "$HOME" -type l | wc -l)" -eq 1 ]
}

@test "register resolves a relative file from the caller's directory" {
    cd "$work"
    run main register ./hello.sh hello
    [ "$status" -eq 0 ]
    [ "$(readlink "$SKOGAI_COMMANDS/hello.sh")" = "$work/hello.sh" ]
}

@test "the command is described by the script's about, not its long_about" {
    main register "$work/hello.sh" hello
    run main --help
    [[ "$output" == *"hello"*"greets people"* ]]
    [[ "$output" != *"second line"* ]]
}

@test "a registered command runs from the directory skogai was called in" {
    main register "$work/hello.sh" hello
    cd "$HOME/sub"
    run main hello where
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/sub" ]
}

@test "the script's own spec is enforced before it runs" {
    main register "$work/hello.sh" hello
    run main hello greet carol
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid choice"*carol* ]]
    [[ "$output" != *"hi carol"* ]]
}

@test "registering the same name again repoints it" {
    main register "$work/hello.sh" hello
    cp "$work/hello.sh" "$work/other.sh"
    run main register "$work/other.sh" hello
    [ "$status" -eq 0 ]
    [ "$(readlink "$SKOGAI_COMMANDS/hello.sh")" = "$work/other.sh" ]
}

@test "names that are not lowercase single segments are refused" {
    for name in Hello hello.world hello_world -hello 1hello; do
        run main register "$work/hello.sh" "$name"
        [ "$status" -eq 2 ]
    done
    [ ! -e "$SKOGAI_COMMANDS" ] || [ -z "$(ls -A "$SKOGAI_COMMANDS")" ]
}

@test "the main's own commands are reserved" {
    for name in register unregister ls help; do
        run main register "$work/hello.sh" "$name"
        [ "$status" -eq 2 ]
        [[ "$output" == *reserved* ]]
    done
}

@test "builtins, keywords and tool names are fine names: nothing becomes a function" {
    for name in echo cd if 'done' sed mv rm; do
        run main register "$work/hello.sh" "$name"
        [ "$status" -eq 0 ]
    done
    run main if greet alice
    [ "$output" = "hi alice" ]
    run main unregister rm
    [ "$status" -eq 0 ]
    [ ! -e "$SKOGAI_COMMANDS/rm.sh" ]
}

@test "a script that is not a valid usage script is refused and not linked" {
    for name in broken plain; do
        run main register "$work/$name.sh" "$name"
        [ "$status" -ne 0 ]
        [ ! -L "$SKOGAI_COMMANDS/$name.sh" ]
    done
}

@test "a missing file is refused" {
    run main register "$work/nope.sh" nope
    [ "$status" -ne 0 ]
    [ ! -L "$SKOGAI_COMMANDS/nope.sh" ]
}

@test "unregister removes the link and the command" {
    main register "$work/hello.sh" hello
    run main unregister hello
    [ "$status" -eq 0 ]
    [ ! -L "$SKOGAI_COMMANDS/hello.sh" ]
    run main --help
    [[ "$output" != *hello* ]]
}

@test "a command whose file is gone leaves help and fails with a clear error" {
    main register "$work/hello.sh" hello
    rm "$work/hello.sh"
    run main --help
    [ "$status" -eq 0 ]
    [[ "$output" != *greets* ]]
    run main hello greet
    [ "$status" -eq 1 ]
    [[ "$output" == "hello: $work/hello.sh is gone"* ]]
}

@test "a script without an about is listed and runs" {
    # shellcheck disable=SC2016 # $usage_x is for the script
    printf '#!/usr/bin/env -S usage bash\n#USAGE arg "<x>"\necho "got $usage_x"\n' >"$work/bare.sh"
    main register "$work/bare.sh" bare
    run main --help
    [ "$status" -eq 0 ]
    [[ "$output" == *bare* ]]
    run main bare 1
    [ "$output" = "got 1" ]
}

@test "a script broken after registering fails alone" {
    main register "$work/hello.sh" hello
    cp "$work/hello.sh" "$work/kept.sh"
    main register "$work/kept.sh" kept
    cp "$work/broken.sh" "$work/hello.sh"
    run main hello
    [ "$status" -ne 0 ]
    run main kept greet bob
    [ "$output" = "hi bob" ]
    run main --help
    [ "$status" -eq 0 ]
    [[ "$output" == *kept* ]]
}

@test "ls marks gone targets" {
    main register "$work/hello.sh" hello
    cp "$work/hello.sh" "$work/kept.sh"
    main register "$work/kept.sh" kept
    rm "$work/hello.sh"
    run main ls
    [[ "${lines[0]}" == hello*"$work/hello.sh (gone)" ]]
    [[ "${lines[1]}" == kept*"$work/kept.sh" ]]
    [[ "${lines[1]}" != *gone* ]]
}

@test "ls lines up targets past the longest name" {
    main register "$work/hello.sh" a-rather-long-command-name
    main register "$work/hello.sh" b
    run main ls
    local first="${lines[0]%%/*}" second="${lines[1]%%/*}"
    [ "${#first}" -eq "${#second}" ]
}

@test "completion of a registered command comes from its own spec" {
    main register "$work/hello.sh" hello
    run complete ""
    [[ "$output" == *hello* && "$output" == *register* ]]
    [[ "$output" != *_mount* ]]
    run complete hello ""
    [[ "$output" == *greet* && "$output" == *where* ]]
    run complete hello greet ""
    [[ "$output" == *alice* && "$output" == *bob* ]]
}

@test "unregister completes registered names" {
    main register "$work/hello.sh" hello
    run complete unregister ""
    [ "$output" = hello ]
}

@test "the runner declares its effects for agents" {
    run usage g json -f "$SKOGAI_MAIN"
    [ "$status" -eq 0 ]
    [ "$(jq -c '[.cmd.subcommands | (.ls, .register, .unregister) | .effect]' <<<"$output")" = '["read","write","write"]' ]
}

@test "the main uses no sed or awk" {
    run grep -nwE 'sed|awk' "$SKOGAI_MAIN"
    [ "$status" -eq 1 ]
}
