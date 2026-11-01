#!/bin/bash
# Mostra as últimas linhas do log do shell do Psito na VM. LOG=labwc mostra
# o do compositor, e LOG=greeter o da tela de login.

VM_USER="psito"
VM_HOST="localhost"
VM_PORT="${VM_PORT:-2222}"
LINES="${1:-40}"

if [ "${LOG:-shell}" = labwc ]; then
    CMD="sudo journalctl -t labwc -n $LINES --no-pager -o short-monotonic"
elif [ "${LOG:-shell}" = greeter ]; then
    CMD="sudo journalctl -u greetd _COMM=psito_greeter _COMM=cage -n $LINES --no-pager -o short-monotonic"
else
    CMD="journalctl --user -u psito-shell -n $LINES --no-pager -o short-monotonic"
fi
ssh -p "$VM_PORT" "$VM_USER@$VM_HOST" "$CMD"
