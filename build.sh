#!/bin/bash
# Compila o shell (shell/) e o host dos apps (apps/) dentro da VM, com o
# Flutter que o provision.sh instalou: o binário liga no GTK e no
# gtk-layer-shell da VM. Leva junto o system_shell e o psito_sdk
# (dependências de caminho), nos mesmos caminhos relativos.
# Uso: ./build.sh [release|profile|debug]   (padrão: release)
# A VM do spike: VM_PORT=2223 ./build.sh
set -e

cd "$(dirname "$0")"

MODE="${1:-release}"
VM_PORT="${VM_PORT:-2222}"
EXCLUDES=(--exclude build/ --exclude .dart_tool/ --exclude linux/flutter/ephemeral/)

echo "📦 [Psito OS] Enviando o código..."
for dir in shell apps system_shell packages/psito_sdk; do
    ssh -p "$VM_PORT" psito@localhost "mkdir -p psito-src/$dir"
    rsync -az --delete "${EXCLUDES[@]}" -e "ssh -p $VM_PORT" \
        "$dir/" "psito@localhost:psito-src/$dir/"
done

echo "🔨 [Psito OS] flutter build linux --$MODE na VM..."
ssh -p "$VM_PORT" psito@localhost "
    set -e
    for app in shell apps; do
        cd ~/psito-src/\$app
        ~/flutter/bin/flutter build linux --$MODE 2>&1 | grep -E 'error|warning|✓' | tail -n 20
    done
    echo $MODE > ~/psito-src/.mode
"
echo "✅ [Psito OS] Build concluído. Rode ./deploy.sh para instalar."
