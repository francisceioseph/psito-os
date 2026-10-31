#!/bin/bash
set -e

echo "🦜 Subindo o Psito OS (Debian + QEMU)..."

# Garantir que estamos na raiz do repositório
cd "$(dirname "$0")"

# Variáveis opcionais: DISK, SSH_PORT, MEM, AUDIO, MONITOR
DISK="${DISK:-qemu/psito-disk.qcow2}"
SSH_PORT="${SSH_PORT:-2222}"
MEM="${MEM:-2048}"
# Backend de som do host (pipewire, pa) ou none: a placa existe, sem saída
AUDIO="${AUDIO:-pipewire}"
MONITOR="${MONITOR:-qemu/monitor.sock}"

# Mapeamento moderno de rede usando netdev + virtio-net-pci
QEMU_ARGS=(
    -m "$MEM"
    -smp 2
    -drive "file=$DISK,format=qcow2"
    -device virtio-vga-gl
    -display gtk,gl=on
    -netdev "user,id=net0,hostfwd=tcp::$SSH_PORT-:22"
    -device virtio-net-pci,netdev=net0
    -audiodev "$AUDIO,id=snd0"
    -device ich9-intel-hda
    -device hda-output,audiodev=snd0
    # Monitor para o ./vm-ctl.sh (ex.: derrubar a rede com set_link)
    -monitor "unix:$MONITOR,server,nowait"
)

if [ -e /dev/kvm ]; then
    QEMU_ARGS+=(-enable-kvm -cpu host)
    echo "-> Aceleração KVM e repasse de CPU ativados!"
fi

qemu-system-x86_64 "${QEMU_ARGS[@]}"
