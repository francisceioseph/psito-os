#!/bin/bash
set -e

# Uso: ./build.sh [release|profile|debug]   (padrão: release)
MODE="${1:-release}"

echo "🔨 [Psito OS] Compilando o shell em modo $MODE..."

# Garantir que estamos no diretório do script (raiz do repositório)
cd "$(dirname "$0")"

export PATH="$PATH:$HOME/.pub-cache/bin"
if ! command -v flutterpi_tool >/dev/null; then
    echo "❌ flutterpi_tool não encontrado. Instale com:"
    echo "   flutter pub global activate --source git https://github.com/ardera/flutterpi_tool"
    exit 1
fi

cd ./system_shell
flutter pub get >/dev/null

# Gera o bundle (assets + app.so AOT + engine do mesmo modo) para o flutter-pi
flutterpi_tool build --arch=x64 "--$MODE"

BUNDLE_DIR=$(find build/flutter-pi -mindepth 1 -maxdepth 1 -type d | head -n 1)
if [ -z "$BUNDLE_DIR" ]; then
    echo "❌ [Psito OS] Bundle do flutter-pi não encontrado em system_shell/build/flutter-pi"
    exit 1
fi

# O deploy.sh lê isto para saber o que enviar e com qual modo iniciar o flutter-pi
printf 'BUNDLE_DIR=%s\nMODE=%s\n' "$BUNDLE_DIR" "$MODE" > build/psito-build.env

echo "📦 Bundle em system_shell/$BUNDLE_DIR:"
ls -1 "$BUNDLE_DIR" | sed 's/^/   /'
echo "✅ [Psito OS] Build concluído com sucesso!"
