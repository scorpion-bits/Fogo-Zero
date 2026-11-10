#!/usr/bin/env bash
# Grava o modo demonstração em 1920×1080 / 60 fps (Movie Maker da Godot) e converte para MP4.
# Uso: ferramentas/gravar_demo.sh [saida.mp4]      (precisa de ffmpeg; GODOT=/caminho/godot opcional)
set -euo pipefail
cd "$(dirname "$0")/.."
SAIDA="${1:-capturas/demo.mp4}"
GODOT="${GODOT:-godot}"
TEMP="$(mktemp -d)"
# override.cfg muda o tamanho da janela só durante a gravação.
cat > override.cfg <<CFG
[display]
window/size/window_width_override=1920
window/size/window_height_override=1080
CFG
trap 'rm -f override.cfg; rm -rf "$TEMP"' EXIT
"$GODOT" --path . --write-movie "$TEMP/demo.avi" -- --demo
ffmpeg -v error -y -i "$TEMP/demo.avi" -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -an "$SAIDA"
echo "Vídeo salvo em $SAIDA"
