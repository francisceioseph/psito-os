#!/bin/bash
set -e

echo "🚀 [Psito OS] Iniciando deploy para a VM Debian..."

# Garantir que estamos na raiz do repositório
cd "$(dirname "$0")"

VM_USER="psito"
VM_HOST="localhost"
VM_PORT="${VM_PORT:-2222}"
DEST_DIR="/opt/psito-app"
BUILD_ENV="system_shell/build/psito-build.env"

# Verificar se existe um build do flutterpi_tool
if [ ! -f "$BUILD_ENV" ]; then
    echo "⚠️  [Psito OS] Bundle não encontrado! Rodando build.sh..."
    ./build.sh
fi
source "$BUILD_ENV"

# O flutter-pi do bundle não tem nosso patch: a VM usa o de /usr/local/bin.
# flutter_engine/ é o cache de shaders que o engine grava na pasta do app.
echo "📦 Transferindo bundle ($MODE) para $DEST_DIR na VM..."
rsync -az --delete --exclude /flutter-pi --exclude /flutter_engine -e "ssh -p $VM_PORT" \
    "system_shell/$BUNDLE_DIR/" "$VM_USER@$VM_HOST:$DEST_DIR/"

echo "🔄 Reiniciando o serviço do Psito OS na VM..."
ssh -p "$VM_PORT" "$VM_USER@$VM_HOST" \
    "echo 'FLUTTER_PI_ARGS=--$MODE' | sudo tee /etc/default/psito-os >/dev/null && sudo systemctl restart psito-os.service"

echo "✨ [Psito OS] Deploy finalizado com sucesso!"
