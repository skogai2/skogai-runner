# installation

```
install :: package -> prefix -> files        pacman's, once per upgrade
add     :: module  -> layer  -> files        skogai's, any time
```

## who owns what

pacman owns what it ships. skogai never writes below `/usr`, and never
into a file pacman owns.

| path | what | written by |
|---|---|---|
| `/usr/bin/skogai` | the binary | pacman |
| `/usr/share/skogai/modules/<name>/` | sources: `module.md`, command, `env`, `files:` | pacman |
| `/usr/share/man/man1/skogai*.1` | man pages of the shipped modules | pacman (made in `build()`) |
| `/usr/share/bash-completion/completions/skogai` | completions | pacman |
| `/usr/share/zsh/site-functions/_skogai` | " | pacman |
| `/usr/share/fish/vendor_completions.d/skogai.fish` | " | pacman |
| `/etc/skogai/` | system layer: the dir only | pacman makes it, the admin fills it |
| `/etc/skogai/modules/<name>/module.md` | a system override | `skogai system add --to system` (root) |
| `~/.config/skogai/` | global layer (`$XDG_CONFIG_HOME`) | the user |
| `<repo>/.skogai/modules/<name>/` | local layer | the user, `skogai system add` |
| `<repo>/.skogai/bin/skogai` | local runner, help and completion for local modules | `skogai system build` |
| `<repo>/.skogai/bin/skogai-<name>` | subcommands | `skogai system add` |
| `<repo>/.skogai/tmp/` | throwaway | anything |

an upgrade replaces the sources in `/usr/share`; an installed copy in a layer
stays as it was. `skogai system diff <name>` shows what changed.

## the prefix

the binary knows its prefix from where it is, nothing else is configured:

| binary | prefix | sources | system layer |
|---|---|---|---|
| `/usr/bin/skogai` | `/usr` | `/usr/share/skogai/modules` | `/etc/skogai` |
| `<sandbox>/usr/bin/skogai` | `<sandbox>/usr` | `<sandbox>/usr/share/skogai/modules` | `<sandbox>/etc/skogai` |
| `<checkout>/bin/skogai` | `<checkout>` | `<checkout>/share/skogai/modules` | `<checkout>/etc/skogai` |

the system layer is `${prefix%/usr}/etc/skogai`: `/usr` gives `/etc`, as the
FHS puts it.

## where the layers are

each has a default and an env that overrides it; nothing else moves them:

| | default | env |
|---|---|---|
| system | `${prefix%/usr}/etc/skogai` | `SKOGAI_SYSTEM_DIR` |
| global | `${XDG_CONFIG_HOME:-~/.config}/skogai` | `SKOGAI_CONFIG_DIR` |
| local | nearest `.skogai/bin/skogai`, else the git root's `.skogai` | `SKOGAI_LOCAL_DIR` |
| sources | `<prefix>/share/skogai/modules` | `SKOGAI_MODULE_PATH`, prepended |

## the PKGBUILD

```bash
pkgname=skogai
pkgver=0.1.0
pkgrel=1
pkgdesc='skogai: modules over argc, layered like the FHS'
arch=(any)
depends=(bash argc go-yq git)
optdepends=('mise: config layers through mise'
            'bats: skogai test')
source=("git+file://$HOME/.local/src/skogai-runner")
sha256sums=(SKIP)

build() {
    cd skogai-runner
    # man pages and completions of the shipped modules, nothing local
    SKOGAI_LOCAL_DIR="$srcdir/empty" SKOGAI_CONFIG_DIR="$srcdir/empty" \
        bin/skogai system build --to global --shell bash >/dev/null
}

package() {
    cd skogai-runner
    install -Dm755 bin/skogai "$pkgdir/usr/bin/skogai"
    install -d "$pkgdir/usr/share/skogai"
    cp -r --no-preserve=ownership modules "$pkgdir/usr/share/skogai/modules"
    install -d "$pkgdir/etc/skogai"
    # man pages and completions from build() into /usr/share/{man,bash-completion,zsh,fish}
}
```

- `go-yq`, not `yq`: arch's `yq` is the python jq wrapper; skogai needs
  mikefarah's (`--front-matter=extract`).
- `argc` is AUR only (1.24.0-1), so skogai is an AUR package too, or
  vendors argc's binary. `go-yq` is in extra (4.54.1).
- `backup=()` stays empty while `/etc/skogai` ships no files. once it ships
  one, it goes in `backup` so pacman keeps the admin's edits (`.pacnew`).
- the man pages and completions of local modules are not pacman's: they come
  from `skogai system build`, in the repo's `.skogai`.

## open

1. `share/skogai/modules` in the checkout is a link to `modules/`; move
   `modules/` there for real, or keep the link.
