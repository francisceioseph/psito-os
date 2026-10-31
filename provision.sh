#!/bin/bash
set -e

echo "🦜 [Psito OS] Provisionando a VM Debian..."

# Garantir que estamos na raiz do repositório
cd "$(dirname "$0")"

VM_USER="psito"
VM_HOST="localhost"
VM_PORT="${VM_PORT:-2222}"
STAGING="/tmp/psito-provision"

# O shell e os apps são compilados dentro da VM, com a mesma versão do Flutter do host
FLUTTER_VERSION="3.47.4"

echo "📦 Enviando arquivos de provisionamento..."
ssh -o StrictHostKeyChecking=accept-new -p "$VM_PORT" "$VM_USER@$VM_HOST" "mkdir -p $STAGING"
rsync -az --delete -e "ssh -p $VM_PORT" vm/ "$VM_USER@$VM_HOST:$STAGING/"

echo "🔧 Rodando o provisionamento na VM..."
ssh -t -o StrictHostKeyChecking=accept-new -p "$VM_PORT" "$VM_USER@$VM_HOST" \
    "sudo APP_USER=$VM_USER FLUTTER_VERSION=$FLUTTER_VERSION bash $STAGING/provision-guest.sh"

echo "✨ [Psito OS] VM pronta! Rode ./build.sh e ./deploy.sh para instalar o shell."
