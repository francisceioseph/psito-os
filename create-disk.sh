#!/bin/bash

set -e

echo "🦜 Create do Psito OS Disk (Debian + QEMU)..."

# Garantir que estamos na raiz do repositório
cd "$(dirname "$0")"

DISK="${DISK:-qemu/psito-disk.qcow2}"
SIZE="${SIZE:-20G}"

# qemu-img sobrescreve sem perguntar: não apagar uma VM existente por engano
if [ -e "$DISK" ]; then
    echo "❌ $DISK já existe. Apague-o antes se quiser mesmo recriar a VM."
    exit 1
fi

mkdir -p "$(dirname "$DISK")"
qemu-img create -f qcow2 "$DISK" "$SIZE"
