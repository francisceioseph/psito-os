#!/bin/bash
# Instala o que o build.sh compilou na VM: o shell em /opt/psito/shell e os
# apps como pacotes .deb (tools/psito-deb): o psito-flutter-runtime e um
# psito-app-<id> por app, instalados com o apt. O launcher e a dock do shell
# leem os .desktop que os pacotes põem em /usr/share/applications. Depois
# reinicia o shell, se a sessão do labwc estiver rodando.
# Os pacotes só saem de um build de release: em profile ou debug, os apps
# instalados ficam como estão.
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
    if [ "$mode" = release ]; then
        debs=~/psito-src/debs
        rm -rf $debs && mkdir -p $debs
        first=
        for dir in ~/psito-src/apps/*/; do
            [ -f $dir/pubspec.yaml ] || continue
            [ -n "$first" ] || first=$dir
            ~/psito-src/tools/psito-deb -o $debs $dir >/dev/null
        done
        ~/psito-src/tools/psito-deb -o $debs --runtime $first >/dev/null
        # O build de desenvolvimento repete a versão: --reinstall
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --reinstall \
            $debs/*.deb >/dev/null
        echo "📦 $(ls $debs | tr "\n" " ")"
        # O que o deploy das versões antigas deixou (cópias em /opt)
        rm -rf /opt/psito/apps
        rm -f ~/.local/share/applications/org.psito.*.desktop
    else
        echo "⚠️  Em $mode os apps não são empacotados: ficam os instalados."
    fi
    if systemctl --user is-active -q psito-shell.service; then
        systemctl --user restart psito-shell.service
    fi
'
echo "✨ [Psito OS] Deploy finalizado ($(ssh -p "$VM_PORT" psito@localhost cat psito-src/.mode))."
