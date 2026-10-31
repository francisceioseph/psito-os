# Wayfire

Wayfire 0.9.0 do Debian 13 (wlroots 0.18), sem o wf-shell, na VM do spike em 31/10/2026. Configuração em [`../guest/wayfire.ini`](../guest/wayfire.ini), instalada em `~/.config/wayfire.ini`. Os números estão em [`../results/wayfire.csv`](../results/wayfire.csv) e os protocolos em [`../results/wayfire-protocolos.txt`](../results/wayfire-protocolos.txt).

## Como rodou
- Sobe de primeira no tty1 (`spike/session.sh wayfire`), sem root. O modo vem do próprio `wayfire.ini` (`[output:Virtual-1] mode = 1440x900`).
- **O wf-shell fica de fora:** instalado com `--no-install-recommends` e `autostart_wf_shell = false`. O `waybar` sobe pelo `[autostart]`.
- **Cursor e mouse:** com o cursor por hardware, o wlroots desenha o cursor de cabeça para baixo no plano de cursor do virtio-gpu. O `session.sh` sobe com `WLR_NO_HARDWARE_CURSORS=1`. O mouse PS/2 do QEMU é relativo e se desencontra do ponteiro do host, então a VM do spike sobe com um tablet USB (`TABLET=1` no `run.sh`, ligado pelo `spike/vm.sh`).
- **Apps:** o `firefox-esr` abre e navega, e o `foot` e o `gtk4-demo` funcionam.

## Protocolos são plugins
Com a lista padrão de plugins, o Wayfire não anuncia foreign-toplevel, `xdg-activation`, session-lock nem `text-input-v3`. Cada um é um plugin, e só existe se estiver em `[core] plugins`: `foreign-toplevel`, `xdg-activation`, `session-lock` e `input-method-v1`. Com eles ligados, faltam:
- `ext_foreign_toplevel_list_v1` e `ext_workspace_manager_v1`: as áreas de trabalho ficam só no IPC;
- `wp_cursor_shape_manager_v1`;
- `ext_image_copy_capture_manager_v1` (o labwc também não tem).

## Foreign-toplevel
Igual ao labwc: o `wlrctl` lista as janelas e `focus`, `minimize` e `maximize` funcionam.

## IPC
O plugin `ipc` abre um socket em `/tmp/wayfire-wayland-1.socket` (o caminho também vem na variável `WAYFIRE_SOCKET` dos filhos). Mensagens JSON com 4 bytes de tamanho na frente. São 42 métodos com os plugins ligados; os que interessam ao Psito:
- **`window-rules/list-views`, `view-info`, `focus-view`, `close-view`, `configure-view` (geometria) e `events/watch`:** o mesmo que o foreign-toplevel, e mais (geometria, área de trabalho, papel da superfície);
- **`wm-actions/set-minimized`, `set-always-on-top`, `set-fullscreen`, `toggle_showdesktop`**, `grid/slot_*` (snap), `scale/toggle` e `vswitch/set-workspace`;
- **`command/register-binding`:** o shell registra um atalho global em tempo de execução e recebe o evento quando ele é apertado. Testado só o registro; o evento fica para a etapa 4;
- **`wayfire/set-config-options` e `get-config-option`:** muda qualquer opção ao vivo. Mudei `decoration/active_color` para o azul do Psito e a moldura mudou na hora.

## A ponte
Duas formas, e as duas funcionam ao vivo:
- **Editar o `wayfire.ini`:** o Wayfire relê o arquivo sozinho quando ele muda (mesmo pid). Ao salvar com plugins novos na lista, eles carregaram sem reiniciar.
- **Pelo IPC:** `wayfire/set-config-options`, sem tocar no arquivo.

Como no labwc, a cor só vale para os apps que pedem moldura ao compositor (o `foot`). O GTK e o Firefox desenham a própria (ver [`labwc.md`](labwc.md)).

Comparado com o labwc, o Wayfire dispensa o `--reconfigure` e deixa o shell ser dono dos atalhos pelo IPC, em vez de gerar uma tabela de `Execute`.

## Roteiro na janela do QEMU
Conferido pelo Francisco: `waybar` com zona exclusiva, snap (`grid`), Ctrl+Tab (`switcher`), minimizar e fechar, as animações de abrir (zoom) e fechar (fade), a visão geral do `scale` (Ctrl+Alt+S), as molduras e a barra de tarefas do `waybar`.

## Números (ao lado do Weston e do labwc)
Duas rodadas com `spike/measure.sh wayfire wayfire`, sem o `waybar` e sem o Firefox. As rodadas deram praticamente os mesmos números; a tabela mostra a segunda.

| Métrica | Weston | labwc | Wayfire |
|---|---|---|---|
| Memória própria do compositor (PSS anônimo), 0 / 5 clientes | 26,9 / 27,6 MB | 32,3 / 32,3 MB | 30,5 / 30,5 MB |
| PSS total do compositor, 0 clientes | 81,5 MB | 95,5 MB | 71,6 MB |
| CPU do compositor parado, 0 / 5 clientes | 0 / 0% | 0 / 0% | 0 / 0% |
| Entrega da tecla, mediana / p95 (1 cliente) | 0,56 / 6,9 ms | 0,54 / 0,84 ms | 0,65 / 1,1 ms |
| Tecla até o frame pronto, mediana / p95 (1 cliente) | 15,4 / 35,5 ms | 13,6 / 20,2 ms | 13,8 / 20,8 ms |
| fps do probe animado, 1 / 5 clientes | 53 / 33 | 60 / 59,4 | 59,3 / 57,9 |
| Tempo de frame do probe, p95, 1 / 5 clientes | 14,6 / 15,8 ms | 0,8 / 10,4 ms | 7,6 / 5,4 ms |

### Leitura
- **Desempenho empatado com o labwc:** parado de verdade (0% de CPU), memória estável e perto de 60 fps. A entrega da tecla é 0,1 ms mais lenta, o que não se sente.
- **As animações não entram na medição:** o `measure.sh` não abre nem fecha janelas durante o fps.

## Para a decisão
- **A favor:**
  - **animações** de abrir, fechar e minimizar, e a visão geral (`scale`, `expo`), que o labwc não tem;
  - **IPC completo:** janelas, eventos, atalhos registrados pelo shell e configuração ao vivo. A ponte fica mais simples e mais poderosa;
  - recarrega o `wayfire.ini` sozinho.
- **Contra:**
  - faltam `ext-workspace` e `cursor-shape`: as áreas de trabalho do shell teriam que vir pelo IPC, preso ao Wayfire;
  - os protocolos dependem da lista de plugins, e esquecer um plugin some com um protocolo sem aviso;
  - mais peças e mais configuração que o labwc.
