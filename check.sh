#!/bin/bash
# Roda o analyzer e imprime só os problemas encontrados.

cd "$(dirname "$0")/system_shell"

OUT=$(flutter analyze --no-pub 2>&1)
STATUS=$?

ISSUES=$(echo "$OUT" | grep -E '^\s*(error|warning|info) •')
if [ -n "$ISSUES" ]; then
    echo "$ISSUES"
elif [ $STATUS -ne 0 ]; then
    echo "$OUT" | tail -n 20
else
    echo "✅ Nenhum problema."
fi

exit $STATUS
