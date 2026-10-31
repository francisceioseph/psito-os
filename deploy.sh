#!/bin/bash
# Instala o que o build.sh compilou na VM, tudo como pacotes .deb
# (tools/psito-deb): o psito-flutter-runtime, o psito-shell (o shell, a
# sessão e o sandbox), um psito-app-<id> por app e o metapacote
# psito-desktop, instalados com o apt. Depois reinicia o shell, se a sessão do
# labwc estiver rodando.
# Os pacotes só saem de um build de release: em profile ou debug, o shell vai
# por cima do pacote instalado (até o próximo deploy de release) e os apps
# ficam como estão.
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
    deb=~/psito-src/tools/psito-deb
    if [ "$mode" = release ]; then
        debs=~/psito-src/debs
        rm -rf $debs && mkdir -p $debs
        $deb -o $debs --runtime ~/psito-src/shell >/dev/null
        $deb -o $debs --system ~/psito-src/shell >/dev/null
        apps=()
        for dir in ~/psito-src/apps/*/; do
            [ -f $dir/pubspec.yaml ] || continue
            apps+=("$(dpkg-deb -f "$($deb -o $debs $dir)" Package)")
        done
        version=$(sed -n "s/^version: *//p" ~/psito-src/shell/pubspec.yaml)
        $deb -o $debs --meta psito-desktop "$version" psito-shell "${apps[@]}" >/dev/null
        # O que as versões antigas instalavam à mão ganharia do pacote
        sudo rm -rf /opt/psito /usr/local/bin/psito-shell-start /usr/local/bin/psito-sandbox
        rm -f ~/.config/systemd/user/psito-shell.service \
            ~/.config/xdg-desktop-portal/labwc-portals.conf \
            ~/.local/share/applications/org.psito.*.desktop
        # O build de desenvolvimento repete a versão: --reinstall
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --reinstall \
            $debs/*.deb >/dev/null
        echo "📦 $(ls $debs | tr "\n" " ")"
    else
        sudo rsync -a ~/psito-src/shell/build/linux/x64/$mode/bundle/ /usr/lib/psito/shell/
        echo "⚠️  Em $mode o shell vai por cima do pacote, e os apps ficam os instalados."
    fi
    systemctl --user daemon-reload
    if systemctl --user is-active -q psito-shell.service; then
        systemctl --user restart psito-shell.service
    fi
'
echo "✨ [Psito OS] Deploy finalizado ($(ssh -p "$VM_PORT" psito@localhost cat psito-src/.mode))."
