#!/bin/bash
# Mostra as últimas linhas do log do serviço Psito OS na VM.

VM_USER="psito"
VM_HOST="localhost"
VM_PORT="${VM_PORT:-2222}"
LINES="${1:-40}"

ssh -p "$VM_PORT" "$VM_USER@$VM_HOST" "sudo journalctl -u psito-os -n $LINES --no-pager -o short-monotonic"
