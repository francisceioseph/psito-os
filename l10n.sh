#!/bin/bash
# Gera as traduções (lib/l10n/*.dart, a partir dos .arb) de cada projeto que tem
# l10n.yaml. O flutter gera sozinho só no projeto que está compilando, e não
# nos pacotes por caminho: por isso o resultado fica no git.

cd "$(dirname "$0")"

STATUS=0
for yaml in packages/*/l10n.yaml system_shell/l10n.yaml shell/l10n.yaml apps/*/l10n.yaml examples/*/l10n.yaml; do
    [ -f "$yaml" ] || continue
    dir=$(dirname "$yaml")
    OUT=$(cd "$dir" && flutter gen-l10n 2>&1) || { echo "❌ $dir:"; echo "$OUT"; STATUS=1; }
done
exit $STATUS
