# hello

The smallest module in format v1 (see [docs/module.md](../../../docs/module.md)). Its declaration is `hello.toml`, a mise config file.

## What it is

`mise run hello <who>` prints `<greeting> <who>` and keeps the same line in `greeting.txt`.

## Keys it sets

- `SKOGAI_HELLO_GREETING`: the greeting, default `hi`. The default is `get_env`, so a caller's `SKOGAI_HELLO_GREETING=yo` wins.
- `_.skogai.hello`: `description`, `owns`, `writes`.
- `tasks.hello`: `usage` (one required argument, `who`) and `run`.

## What it owns

`greeting.txt`, relative to where the module runs. It also writes it, which is allowed because it owns it.

## Try it

```sh
mkdir -p p/.mise/conf.d && cp hello.toml p/.mise/conf.d/ && cd p
mise run -q hello world        # hi world
SKOGAI_HELLO_GREETING=yo mise run -q hello world   # yo world
```
