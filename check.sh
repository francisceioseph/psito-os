#!/bin/bash
# Roda o analyzer nos pacotes, no system_shell, no shell e em cada app
# (apps/<id>/) e imprime só os problemas encontrados.

cd "$(dirname "$0")"

STATUS=0
for dir in packages/psito_services packages/psito_runtime system_shell shell apps/*/; do
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
