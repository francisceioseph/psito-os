#!/bin/bash
# Mostra as últimas linhas do log do shell do Psito na VM. LOG=psito-os mostra
# o do labwc (a sessão no tty1).

VM_USER="psito"
VM_HOST="localhost"
VM_PORT="${VM_PORT:-2222}"
LINES="${1:-40}"

if [ "${LOG:-shell}" = psito-os ]; then
    CMD="sudo journalctl -u psito-os -n $LINES --no-pager -o short-monotonic"
else
    CMD="journalctl --user -u psito-shell -n $LINES --no-pager -o short-monotonic"
fi
ssh -p "$VM_PORT" "$VM_USER@$VM_HOST" "$CMD"
