#!/bin/bash
# Instala um app do Psito que está fora da árvore do sistema (como um app de
# terceiro): envia o projeto e os packages/ para a VM, compila em release,
# empacota com o tools/psito-deb e instala com o apt. Não recompila nem
# reinicia o shell: o launcher vê o .desktop novo sozinho.
# Uso: ./install-app.sh <projeto>   (ex.: examples/hello_psito)
set -e

cd "$(dirname "$0")"

PROJECT="${1:?uso: ./install-app.sh <projeto>}"
PROJECT="${PROJECT%/}"
[ -f "$PROJECT/pubspec.yaml" ] || { echo "❌ $PROJECT não é um projeto Flutter" >&2; exit 1; }
VM_PORT="${VM_PORT:-2222}"
EXCLUDES=(--exclude build/ --exclude .dart_tool/ --exclude linux/flutter/ephemeral/)

echo "📦 [Psito OS] Enviando $PROJECT..."
for dir in "$PROJECT" packages tools; do
    ssh -p "$VM_PORT" psito@localhost "mkdir -p psito-src/$dir"
    rsync -az --delete "${EXCLUDES[@]}" -e "ssh -p $VM_PORT" \
        "$dir/" "psito@localhost:psito-src/$dir/"
done

echo "🔨 [Psito OS] Compilando e empacotando na VM..."
ssh -p "$VM_PORT" psito@localhost "
    set -e
    cd ~/psito-src/$PROJECT
    ~/flutter/bin/flutter build linux --release 2>&1 | grep -E 'error|✓' | tail -n 20
    rm -rf ~/psito-src/debs-extra && mkdir -p ~/psito-src/debs-extra
    deb=\$(~/psito-src/tools/psito-deb -o ~/psito-src/debs-extra .)
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --reinstall \$deb >/dev/null
    echo \"📦 \$(basename \$deb)\"
"
echo "✅ [Psito OS] Instalado. O app aparece no launcher."
