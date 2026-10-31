#!/bin/bash
# Mede um compositor rodando na VM do spike e grava spike/results/<candidato>.csv.
# Uso: spike/measure.sh <candidato> <processo-do-compositor>
#   ex.: spike/session.sh weston && spike/measure.sh weston weston
# Cenários: memória com 0/1/3/5 clientes, CPU parada com 0 e 5, latência de
# entrada e fps do probe animado com 1 e 5 clientes.
set -e

cd "$(dirname "$0")"

CANDIDATE="$1"
COMPOSITOR="$2"
if [ -z "$CANDIDATE" ] || [ -z "$COMPOSITOR" ]; then
    echo "Uso: spike/measure.sh <candidato> <processo-do-compositor>"
    exit 1
fi
VM_PORT="${VM_PORT:-2223}"
export VM_PORT
RAW="results/raw/$CANDIDATE"
OUT="results/$CANDIDATE.csv"
PROBE=/home/psito/probe/probe
IDLE_SECS="${IDLE_SECS:-30}"

vm() { ssh -p "$VM_PORT" psito@localhost "$@"; }
close_clients() {
    vm "pkill -f '^$PROBE' ; pkill -x foot ; pkill -x gtk4-demo ; pkill -x weston-terminal ; true"
    sleep 2
}
# Abre um cliente e devolve o pid; espera ele aparecer
open_client() {
    local pid
    pid=$(./client.sh "$@")
    sleep 4
    echo "$pid"
}
# Soma de uma coluna das linhas do sample.sh
column() { awk -F, -v c="$1" '{s += $c} END {print s + 0}'; }
metric() { echo "$1,$2" | tee -a "$OUT"; }
# Um compositor que cai no meio invalida o resto: registra e para
alive() {
    if ! vm "kill -0 $comp" 2>/dev/null; then
        metric caiu_durante "$1"
        echo "❌ $COMPOSITOR caiu durante: $1"
        exit 1
    fi
}

comp=$(vm "pgrep -o -x $COMPOSITOR") || {
    echo "❌ $COMPOSITOR não está rodando (spike/session.sh)."
    exit 1
}
mkdir -p "$RAW"
rsync -az -e "ssh -p $VM_PORT" tools/ psito@localhost:/tmp/spike/tools/
vm "rm -f /tmp/spike/*.csv"
close_clients
echo "metrica,valor" > "$OUT"
metric compositor "$CANDIDATE"
metric data "$(date -Iseconds)"

echo "📏 Memória e CPU parada..."
row=$(vm "sudo /tmp/spike/tools/sample.sh $IDLE_SECS $comp")
metric mem_compositor_kib_0 "$(echo "$row" | column 3)"
metric mem_compositor_anon_kib_0 "$(echo "$row" | column 4)"
metric cpu_compositor_parado_pct_0 "$(echo "$row" | column 5)"

clients=()
open_n() {
    while [ "${#clients[@]}" -lt "$1" ]; do
        case "${#clients[@]}" in
            0) clients+=("$(PROBE_NAME=probe1 open_client "$PROBE")") ;;
            1) clients+=("$(open_client foot)") ;;
            2) clients+=("$(open_client gtk4-demo)") ;;
            3) clients+=("$(open_client weston-terminal)") ;;
            4) clients+=("$(PROBE_NAME=probe2 open_client "$PROBE")") ;;
        esac
    done
}
for n in 1 3 5; do
    open_n "$n"
    rows=$(vm "sudo /tmp/spike/tools/sample.sh 2 $comp ${clients[*]}")
    metric "mem_compositor_kib_$n" "$(echo "$rows" | head -n 1 | column 3)"
    metric "mem_compositor_anon_kib_$n" "$(echo "$rows" | head -n 1 | column 4)"
    metric "mem_clientes_kib_$n" "$(echo "$rows" | tail -n +2 | column 3)"
    metric "mem_clientes_anon_kib_$n" "$(echo "$rows" | tail -n +2 | column 4)"
done
rows=$(vm "sudo /tmp/spike/tools/sample.sh $IDLE_SECS $comp ${clients[*]}")
metric cpu_compositor_parado_pct_5 "$(echo "$rows" | head -n 1 | column 5)"
metric cpu_clientes_parado_pct_5 "$(echo "$rows" | tail -n +2 | column 5)"

# Latência e fps com 1 cliente (só o probe) e com 5 (o probe abre por último,
# para ficar com o foco)
for n in 1 5; do
    close_clients
    if [ "$n" = 5 ]; then
        ./client.sh foot >/dev/null
        ./client.sh gtk4-demo >/dev/null
        ./client.sh weston-terminal >/dev/null
        PROBE_NAME=probe2 ./client.sh "$PROBE" >/dev/null
        sleep 4
    fi

    echo "⌨️  Latência com $n cliente(s)..."
    pid=$(PROBE_NAME=latencia PROBE_LOG=/tmp/spike/probe-lat$n.csv open_client "$PROBE")
    vm "sudo python3 /tmp/spike/tools/inject.py > /tmp/spike/inject$n.csv"
    sleep 1
    alive "latencia_$n"
    vm "kill $pid"

    echo "🎞️  fps com $n cliente(s)..."
    pid=$(PROBE_NAME=fps PROBE_ANIMATE=1 PROBE_LOG=/tmp/spike/probe-fps$n.csv open_client "$PROBE")
    sleep 10
    alive "fps_$n"
    vm "kill $pid"
done
close_clients

rsync -az -e "ssh -p $VM_PORT" "psito@localhost:/tmp/spike/*.csv" "$RAW/"
for n in 1 5; do
    python3 -I tools/latency.py "$RAW/inject$n.csv" "$RAW/probe-lat$n.csv" |
        sed "s/^\([^,]*\),/\1_$n,/" | tee -a "$OUT"
    python3 -I tools/fps.py "$RAW/probe-fps$n.csv" "probe_animado_$n" | tee -a "$OUT"
done
echo "✅ $OUT"
