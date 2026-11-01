#!/bin/bash
# Roda o analyzer nos pacotes, no system_shell, no shell e em cada app
# (apps/<id>/ e examples/<id>/) e imprime só os problemas encontrados.

cd "$(dirname "$0")"

# Os textos gerados acompanham os .arb
./l10n.sh || exit 1

STATUS=0
for dir in packages/psito_sdk packages/psito_fs packages/psito_dock packages/psito_desktop packages/psito_files_ui packages/psito_services packages/psito_runtime system_shell shell lock greeter apps/*/ examples/*/; do
    dir=${dir%/}
    OUT=$(cd "$dir" && flutter analyze --no-pub 2>&1)
    CODE=$?
    ISSUES=$(echo "$OUT" | grep -E '^\s*(error|warning|info) •')
    if [ -n "$ISSUES" ]; then
        echo "$dir:"
        echo "$ISSUES"
    elif [ $CODE -ne 0 ]; then
        echo "$dir:"
        echo "$OUT" | tail -n 20
    fi
    [ $CODE -ne 0 ] && STATUS=$CODE
done

[ $STATUS -eq 0 ] && echo "✅ Nenhum problema."
exit $STATUS
