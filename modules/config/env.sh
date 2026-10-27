#!/usr/bin/env bash
# what every skogai command runs with while config is installed: the mise
# layers as export lines, minus the keys the caller's env already says
set -euo pipefail

while IFS= read -r line; do
    name="${line#export }"
    name="${name%%=*}"
    if [[ $name == MISE_OVERRIDE_CONFIG_FILENAMES || -z ${!name+x} ]]; then echo "$line"; fi
done < <(argc --argc-run "$SKOGAI_MODULE_DIR/argc.sh" env)
