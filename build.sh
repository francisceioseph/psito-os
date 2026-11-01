#!/bin/bash
# Compila o shell (shell/) e cada app (apps/<id>/) dentro da VM, com o
# Flutter que o provision.sh instalou: o binário liga no GTK e no
# gtk-layer-shell da VM. Leva junto o system_shell e os packages/
# (dependências de caminho), nos mesmos caminhos relativos, e o tools/ (o
# psito-deb, que o deploy.sh usa).
# Uso: ./build.sh [release|profile|debug]   (padrão: release)
# A VM do spike: VM_PORT=2223 ./build.sh
# Só alguns projetos: ONLY="shell apps/files" ./build.sh
set -e

cd "$(dirname "$0")"

MODE="${1:-release}"
VM_PORT="${VM_PORT:-2222}"
ONLY="${ONLY:-shell lock greeter apps/*/}"
EXCLUDES=(--exclude build/ --exclude .dart_tool/ --exclude linux/flutter/ephemeral/)

echo "📦 [Psito OS] Enviando o código..."
for dir in shell lock greeter apps system_shell packages tools; do
    ssh -p "$VM_PORT" psito@localhost "mkdir -p psito-src/$dir"
    rsync -az --delete "${EXCLUDES[@]}" -e "ssh -p $VM_PORT" \
        "$dir/" "psito@localhost:psito-src/$dir/"
done

echo "🔨 [Psito OS] flutter build linux --$MODE na VM..."
ssh -p "$VM_PORT" psito@localhost "
    set -e
    cd ~/psito-src
    for dir in $ONLY; do
        dir=~/psito-src/\$dir
        [ -f \$dir/pubspec.yaml ] || continue
        cd \$dir
        # O build incremental não refaz a fonte de ícones cortada (só com os
        # ícones usados): um ícone novo saía em branco
        rm -rf build/flutter_assets
        ~/flutter/bin/flutter build linux --$MODE 2>&1 | grep -E 'error|warning|✓' | tail -n 20
    done
    echo $MODE > ~/psito-src/.mode
"
echo "✅ [Psito OS] Build concluído. Rode ./deploy.sh para instalar."
