#!/bin/bash
# Comandos ao monitor do QEMU da VM em execução (aberto pelo run.sh).
#   ./vm-ctl.sh link off|on   derruba ou religa a rede (set_link net0)
#   ./vm-ctl.sh wakeup        acorda a VM suspensa (system_wakeup)
#   ./vm-ctl.sh usb-add <img> liga um pendrive virtual (cria a imagem, de 64 MB, se
#                             não existir; quem formata é a VM: mkfs.vfat /dev/sdb)
#   ./vm-ctl.sh usb-del       puxa o pendrive, sem ejetar
#   ./vm-ctl.sh raw "<cmd>"   qualquer comando do monitor
set -e
cd "$(dirname "$0")"

MONITOR="${MONITOR:-qemu/monitor.sock}"

usage() {
    sed -n '2,7p' "$0" | sed 's/^# \?//'
    exit 1
}

case "$1" in
    link)
        [[ "$2" == on || "$2" == off ]] || usage
        CMD="set_link net0 $2"
        ;;
    wakeup) CMD="system_wakeup" ;;
    usb-add)
        [ -n "$2" ] || usage
        [ -e "$2" ] || qemu-img create -q -f raw "$2" 64M
        IMAGE="$(realpath "$2")"
        CMD="drive_add 0 if=none,id=psitousb,format=raw,file=$IMAGE
device_add usb-storage,id=psitousbdev,drive=psitousb,removable=on"
        ;;
    usb-del) CMD="device_del psitousbdev" ;;
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
