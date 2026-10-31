#!/bin/bash
# Instala o que o build.sh compilou na VM: o shell em /opt/psito/shell, cada
# app em /opt/psito/apps/<id> e os .desktop deles no ~/.local/share/applications
# (o launcher e a dock do shell leem dali). Depois reinicia o shell, se a
# sessão do labwc estiver rodando.
# A VM do spike: VM_PORT=2223 ./deploy.sh
set -e

cd "$(dirname "$0")"

VM_PORT="${VM_PORT:-2222}"

ssh -p "$VM_PORT" psito@localhost 'test -f ~/psito-src/.mode' || {
    echo "⚠️  [Psito OS] Nada compilado na VM. Rodando o build.sh..."
    ./build.sh
}

echo "🚀 [Psito OS] Instalando e reiniciando o shell..."
ssh -p "$VM_PORT" psito@localhost '
    set -e
    mode=$(cat ~/psito-src/.mode)
    rsync -a --delete ~/psito-src/shell/build/linux/x64/$mode/bundle/ /opt/psito/shell/
    mkdir -p ~/.local/share/applications
    rm -f ~/.local/share/applications/org.psito.*.desktop
    rm -rf /opt/psito/apps.new && mkdir -p /opt/psito/apps.new
    for dir in ~/psito-src/apps/*/; do
        [ -f $dir/pubspec.yaml ] || continue
        id=$(basename $dir)
        cp -a $dir/build/linux/x64/$mode/bundle /opt/psito/apps.new/$id
        cp $dir/org.psito.$id.desktop ~/.local/share/applications/
    done
    rm -rf /opt/psito/apps && mv /opt/psito/apps.new /opt/psito/apps
    if systemctl --user is-active -q psito-shell.service; then
        systemctl --user restart psito-shell.service
    fi
'
echo "✨ [Psito OS] Deploy finalizado ($(ssh -p "$VM_PORT" psito@localhost cat psito-src/.mode))."
