#!/bin/bash
set -e

echo "🦜 [Psito OS] Provisionando a VM Debian..."

# Garantir que estamos na raiz do repositório
cd "$(dirname "$0")"

VM_USER="psito"
VM_HOST="localhost"
VM_PORT="2222"
STAGING="/tmp/psito-provision"

# Versão do flutter-pi em que o patch de patches/ foi testado
FLUTTER_PI_COMMIT="f0b3330"

# O engine não é instalado aqui: cada bundle do build.sh leva o seu (mesmo modo e versão do app.so)

echo "📦 Enviando arquivos de provisionamento..."
ssh -p "$VM_PORT" "$VM_USER@$VM_HOST" "mkdir -p $STAGING/patches"
rsync -az -e "ssh -p $VM_PORT" vm/ "$VM_USER@$VM_HOST:$STAGING/"
rsync -az -e "ssh -p $VM_PORT" patches/ "$VM_USER@$VM_HOST:$STAGING/patches/"

echo "🔧 Rodando o provisionamento na VM..."
ssh -t -p "$VM_PORT" "$VM_USER@$VM_HOST" \
    "sudo APP_USER=$VM_USER FLUTTER_PI_COMMIT=$FLUTTER_PI_COMMIT bash $STAGING/provision-guest.sh"

echo "✨ [Psito OS] VM pronta! Rode ./deploy.sh para enviar o shell."
