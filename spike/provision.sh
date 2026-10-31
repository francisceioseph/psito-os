#!/bin/bash
# Prepara a VM do spike. Rode depois do provision.sh normal:
#   spike/vm.sh provision.sh && spike/provision.sh
# Pode ser rodado de novo.
set -e

cd "$(dirname "$0")"

VM_PORT="${VM_PORT:-2223}"
STAGING="/tmp/psito-spike-provision"

echo "📦 Enviando arquivos do spike..."
ssh -o StrictHostKeyChecking=accept-new -p "$VM_PORT" psito@localhost "mkdir -p $STAGING"
rsync -az -e "ssh -p $VM_PORT" guest/ "psito@localhost:$STAGING/"

echo "🔧 Provisionando o spike na VM..."
ssh -t -p "$VM_PORT" psito@localhost \
    "sudo APP_USER=psito bash $STAGING/provision-spike.sh"
