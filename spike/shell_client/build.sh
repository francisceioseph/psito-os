#!/bin/bash
# Compila o shell como cliente layer-shell dentro da VM do spike, como o
# probe. Leva junto o system_shell e o psito_sdk (dependências de caminho),
# nos mesmos caminhos relativos. O bundle fica em /home/psito/shell_client/;
# o autostart do labwc sobe ele no lugar do waybar.
set -e

cd "$(dirname "$0")/../.."

VM_PORT="${VM_PORT:-2223}"
EXCLUDES=(--exclude build/ --exclude .dart_tool/ --exclude linux/flutter/ephemeral/)

echo "📦 Enviando o shell e as dependências..."
for dir in spike/shell_client system_shell packages/psito_sdk; do
    ssh -p "$VM_PORT" psito@localhost "mkdir -p psito-src/$dir"
    rsync -az --delete "${EXCLUDES[@]}" -e "ssh -p $VM_PORT" \
        "$dir/" "psito@localhost:psito-src/$dir/"
done

echo "🔨 flutter build linux --release na VM..."
ssh -p "$VM_PORT" psito@localhost '
    set -e
    cd psito-src/spike/shell_client
    ~/flutter/bin/flutter build linux --release 2>&1 | grep -E "error|warning|✓" | tail -n 20
    rsync -a --delete build/linux/x64/release/bundle/ ~/shell_client/
'
echo "✅ Shell em /home/psito/shell_client/psito_shell_client"
