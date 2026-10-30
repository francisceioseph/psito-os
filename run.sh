#!/bin/bash
set -e

echo "🦜 Subindo o Psito OS (Debian + QEMU)..."

DISK="qemu/psito-disk.qcow2"

# Mapeamento moderno de rede usando netdev + virtio-net-pci
QEMU_ARGS=(
    -m 2048
    -smp 2
    -drive "file=$DISK,format=qcow2"
    -vga virtio
    -display gtk,gl=on
    -netdev user,id=net0,hostfwd=tcp::2222-:22
    -device virtio-net-pci,netdev=net0
)

if [ -e /dev/kvm ]; then
    QEMU_ARGS+=(-enable-kvm -cpu host)
    echo "-> Aceleração KVM e repasse de CPU ativados!"
fi

qemu-system-x86_64 "${QEMU_ARGS[@]}"