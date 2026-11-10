#!/usr/bin/env bash
# Grava o modo demonstração em 1920×1080 / 60 fps e converte para MP4.
# A cena é renderizada fora da tela (SubViewport), então a janela pode ficar minimizada.
# Uso: ferramentas/gravar_demo.sh [saida.mp4]      (precisa de ffmpeg; GODOT=/caminho/godot opcional)
set -euo pipefail
cd "$(dirname "$0")/.."
SAIDA="${1:-capturas/demo.mp4}"
GODOT="${GODOT:-godot}"
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT
"$GODOT" --path . --fixed-fps 60 --resolution 640x360 -s testes/gravar_demo.gd -- --demo --quadros="$TEMP"
ffmpeg -v error -y -framerate 60 -i "$TEMP/q%05d.jpg" -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p "$SAIDA"
echo "Vídeo salvo em $SAIDA"
