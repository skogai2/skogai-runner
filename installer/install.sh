#!/usr/bin/env bash
# install.sh <root> [prefix]: skogai into <root><prefix>, default prefix /usr.
# the binary, the modules as sources, their man pages, and the system layer's
# dir (`${prefix%/usr}/etc/skogai`). package() runs it with "$pkgdir"; any
# other root is a skogai of its own: `install.sh /tmp/try` gives /tmp/try/usr/bin/skogai
set -euo pipefail

root="${1:?usage: install.sh <root> [prefix]}"
prefix="${2:-/usr}"
src="$(cd "$(dirname "$(realpath "$0")")/.." && pwd)"
share="$root$prefix/share"

install -Dm755 "$src/bin/skogai" "$root$prefix/bin/skogai"
install -d "$share/skogai/modules" "$root${prefix%/usr}/etc/skogai"
cp -rT --no-preserve=ownership "$src/modules" "$share/skogai/modules"

# one page per command; argc names them after binname, spaces become dashes
install -d "$share/man/man1"
for md in "$src"/modules/*/module.md; do
    cmd="$(yq --front-matter=extract '.command // ""' "$md")"
    [[ -n $cmd ]] || continue
    argc --argc-mangen "$(dirname "$md")/$cmd" "$share/man/man1" >/dev/null
done
for f in "$share/man/man1"/*' '*; do [[ -e $f ]] && mv "$f" "${f// /-}"; done

# completions: placeholder. argc's need a runner that knows every module,
# which `skogai system build` makes per repo; none is shipped yet
