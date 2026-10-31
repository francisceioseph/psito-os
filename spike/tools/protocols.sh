#!/bin/bash
# Roda dentro da VM, na sessão do compositor. Diz quais protocolos de que o
# Psito depende o compositor anuncia, com a versão.
# Do host: ssh -p 2223 psito@localhost 'bash -s' < spike/tools/protocols.sh \
#              > spike/results/<candidato>-protocolos.txt
set -e

export XDG_RUNTIME_DIR=/run/user/1000
WAYLAND_DISPLAY=$(ls "$XDG_RUNTIME_DIR" | grep -E '^wayland-[0-9]+$' | head -n 1)
export WAYLAND_DISPLAY
if [ -z "$WAYLAND_DISPLAY" ]; then
    echo "❌ Nenhum compositor rodando." >&2
    exit 1
fi

# protocolo  para que o Psito usa
PROTOCOLS="
zwlr_layer_shell_v1                 top bar, dock, launcher e papel de parede
zwlr_foreign_toplevel_manager_v1    lista de janelas com ações (dock, Alt+Tab)
ext_foreign_toplevel_list_v1        lista de janelas, só leitura
ext_workspace_manager_v1            áreas de trabalho
zxdg_decoration_manager_v1          decoração do lado do servidor
xdg_activation_v1                   passar o foco ao abrir um app
wp_cursor_shape_manager_v1          cursor pelo nome
ext_session_lock_manager_v1         tela de bloqueio
zwlr_screencopy_manager_v1          miniaturas das janelas
ext_image_copy_capture_manager_v1   miniaturas das janelas (novo)
zwlr_output_manager_v1              resolução pelas Configurações
wp_fractional_scale_manager_v1      escala fracionária
zwp_linux_dmabuf_v1                 buffers da GPU sem cópia
wp_presentation                     tempo de apresentação dos frames
zwp_text_input_manager_v3           métodos de entrada
zwp_virtual_keyboard_manager_v1     teclado virtual
"

info=$(wayland-info 2>/dev/null)
compositor=$(ps -o comm= -p "$(pgrep -o -x 'weston|labwc|wayfire|zenith')" 2>/dev/null || echo '?')
echo "# compositor: $compositor, $(date -Iseconds)"
printf '%-36s %-5s %-6s %s\n' protocolo tem versão uso
echo "$PROTOCOLS" | while read -r name use; do
    [ -z "$name" ] && continue
    version=$(echo "$info" | grep -oP "interface: '$name',\s*version:\s*\K[0-9]+" | head -n 1)
    if [ -n "$version" ]; then
        printf '%-36s %-5s %-6s %s\n' "$name" sim "$version" "$use"
    else
        printf '%-36s %-6s %-6s %s\n' "$name" não - "$use"
    fi
done
