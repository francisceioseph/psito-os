#!/bin/bash
# VM do spike da fase 3: roda um script da raiz com as variáveis desta VM.
# Ex.: spike/vm.sh create-disk.sh | install-os.sh | provision.sh | run.sh
#      spike/vm.sh ssh [comando]
# Não suba as duas VMs ao mesmo tempo: o host tem pouca RAM.
set -e

cd "$(dirname "$0")/.."

export DISK="${DISK:-qemu/psito-spike.qcow2}"
export SSH_PORT="${SSH_PORT:-2223}"
export VM_PORT="$SSH_PORT"
export MEM="${MEM:-3072}"
export SMP="${SMP:-4}"
export SIZE="${SIZE:-40G}"
export MONITOR="${MONITOR:-qemu/spike-monitor.sock}"
# Os compositores Wayland querem o ponteiro absoluto (ver run.sh)
export TABLET="${TABLET:-1}"

if [ -z "$1" ]; then
    echo "Uso: spike/vm.sh <script da raiz> [args] | ssh [comando]"
    exit 1
fi

if [ "$1" = ssh ]; then
    shift
    exec ssh -o StrictHostKeyChecking=accept-new -p "$SSH_PORT" psito@localhost "$@"
fi

script="$1"
shift
exec "./$script" "$@"
