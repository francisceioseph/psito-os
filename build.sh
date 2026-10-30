#!/bin/bash
set -e

echo "🔨 [Psito OS] Iniciando compilação do bundle Flutter..."

# Garantir que estamos no diretório do script (raiz do repositório)
cd "$(dirname "$0")"

# Entrar no diretório onde está a aplicação Flutter
cd ./system_shell

# Limpar build anterior e buscar dependências
flutter pub get

# Compilar os assets para o formato suportado pelo flutter-pi
flutter build bundle

echo "📦 Copiando icudtl.dat para o bundle de assets..."
FLUTTER_BIN=$(which flutter)
FLUTTER_DIR=$(dirname "$FLUTTER_BIN")

# Busca o icudtl.dat no cache do SDK do Flutter e copia para dentro de build/flutter_assets
cp "$FLUTTER_DIR/cache/artifacts/engine/linux-x64/icudtl.dat" build/flutter_assets/ 2>/dev/null || \
find ~/ -name "icudtl.dat" 2>/dev/null | head -n 1 | xargs -I {} cp {} build/flutter_assets/

echo "✅ [Psito OS] Build concluído com sucesso!"