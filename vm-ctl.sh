#!/bin/bash
# Comandos ao monitor do QEMU da VM em execução (aberto pelo run.sh).
#   ./vm-ctl.sh link off|on   derruba ou religa a rede (set_link net0)
#   ./vm-ctl.sh wakeup        acorda a VM suspensa (system_wakeup)
#   ./vm-ctl.sh raw "<cmd>"   qualquer comando do monitor
set -e
cd "$(dirname "$0")"

MONITOR="${MONITOR:-qemu/monitor.sock}"

usage() {
    sed -n '2,5p' "$0" | sed 's/^# \?//'
    exit 1
}

case "$1" in
    link)
        [[ "$2" == on || "$2" == off ]] || usage
        CMD="set_link net0 $2"
        ;;
    wakeup) CMD="system_wakeup" ;;
    raw)
        [ -n "$2" ] || usage
        CMD="$2"
        ;;
    *) usage ;;
esac

if [ ! -S "$MONITOR" ]; then
    echo "❌ Monitor não encontrado em $MONITOR. A VM está rodando pelo ./run.sh?" >&2
    exit 1
fi

# O monitor responde com um banner e ecoa o comando; mostra só a resposta
printf '%s\n' "$CMD" | socat -t 1 - "UNIX-CONNECT:$MONITOR" \
    | tr -d '\r' | grep -v -e '^QEMU ' -e '^(qemu)' || true
echo "🦜 $CMD"
