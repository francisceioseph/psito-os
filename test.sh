#!/bin/bash
# Roda o flutter test nos pacotes, no system_shell, no shell e nos apps
# (apps/<id>/ e examples/<id>/, os que têm test/) e imprime só as falhas.
# Uso: ./test.sh [pasta...]   (padrão: todos)
# Por padrão, o flutter test abre um processo de teste por núcleo, o que não
# cabe na memória do host com a VM ligada. Aqui são TEST_JOBS processos (padrão
# 2), num escopo do systemd com TEST_MEM de limite (padrão 2G) e sem swap: se
# passar disso, só os testes morrem, e a VM e o resto do host ficam.
# Sem limite: TEST_MEM=0 ./test.sh

cd "$(dirname "$0")"

JOBS="${TEST_JOBS:-2}"
MEM="${TEST_MEM:-2G}"
DIRS=("$@")
[ ${#DIRS[@]} -eq 0 ] && DIRS=(packages/psito_fs packages/psito_services packages/psito_runtime system_shell shell apps/*/ examples/*/)

LIMIT=()
if [ "$MEM" != "0" ] && command -v systemd-run >/dev/null; then
    LIMIT=(systemd-run --user --scope --quiet --collect -p MemoryMax="$MEM" -p MemorySwapMax=0)
fi

STATUS=0
for dir in "${DIRS[@]}"; do
    dir=${dir%/}
    [ -d "$dir/test" ] || continue
    OUT=$(cd "$dir" && "${LIMIT[@]}" flutter test --no-pub -j "$JOBS" -r failures-only 2>&1)
    CODE=$?
    if [ $CODE -ne 0 ]; then
        echo "❌ $dir:"
        # 137 é o SIGKILL do limite de memória
        [ $CODE -eq 137 ] && echo "   morto pelo limite de memória ($MEM). Tente TEST_MEM=3G ou TEST_JOBS=1."
        echo "$OUT" | tail -n 40
        STATUS=$CODE
    else
        echo "✅ $dir"
    fi
done

exit $STATUS
