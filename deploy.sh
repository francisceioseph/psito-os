#!/bin/bash
set -e

echo "🚀 [Psito OS] Iniciando deploy para a VM Debian..."

# Garantir que estamos na raiz do repositório
cd "$(dirname "$0")"

VM_USER="psito"
VM_HOST="localhost"
VM_PORT="2222"
DEST_DIR="/opt/psito-app"

# Verificar se o bundle existe no caminho correto dentro de system_shell
if [ ! -d "system_shell/build/flutter_assets" ]; then
    echo "⚠️  [Psito OS] Bundle não encontrado! Rodando build.sh..."
    ./build.sh
fi

echo "📦 Transferindo assets para $DEST_DIR na VM..."
rsync -avz --delete -e "ssh -p $VM_PORT" system_shell/build/flutter_assets/ "$VM_USER@$VM_HOST:$DEST_DIR/"

echo "🔄 Reiniciando o serviço do Psito OS na VM..."
ssh -p "$VM_PORT" "$VM_USER@$VM_HOST" "sudo chown -R psito:psito /opt/psito-app && sudo chmod -R 755 /opt/psito-app"
ssh -p "$VM_PORT" "$VM_USER@$VM_HOST" "sudo systemctl restart psito-os.service 2>/dev/null || true"

echo "✨ [Psito OS] Deploy finalizado com sucesso!"