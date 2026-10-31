# labwc

labwc 0.8.3 do Debian 13 (wlroots 0.18), na VM do spike em 31/10/2026. Configuração em [`../guest/labwc/`](../guest/labwc/), instalada em `~/.config/labwc` pelo `spike/provision.sh`. Os números estão em [`../results/labwc.csv`](../results/labwc.csv) e os protocolos em [`../results/labwc-protocolos.txt`](../results/labwc-protocolos.txt).

## Como rodou
- Sobe de primeira no tty1 pela sessão do logind (`spike/session.sh labwc`), sem root.
- **Modo da tela:** o labwc não tem modo no `rc.xml`. O `autostart` roda `wlr-randr --output Virtual-1 --mode 1440x900`, e a tela fica em 1440×900@59,9.
- **O `waybar` faz o papel do painel do Psito:** é um cliente layer-shell, sobe pelo `autostart` e reserva 28 px no topo. O módulo `wlr/taskbar` dele usa o `wlr-foreign-toplevel-management`, o mesmo que a dock do Psito vai usar.
- **Cursor e mouse:** com o cursor por hardware, o wlroots desenha o cursor de cabeça para baixo no plano de cursor do virtio-gpu. O `session.sh` sobe com `WLR_NO_HARDWARE_CURSORS=1`. O mouse PS/2 do QEMU é relativo e se desencontra do ponteiro do host, então a VM do spike sobe com um tablet USB (`TABLET=1` no `run.sh`, ligado pelo `spike/vm.sh`).
- **Apps:** o `firefox-esr` 153 abre e navega, e o `foot` e o `gtk4-demo` funcionam.

## Protocolos
Tem todos os que o Psito precisa, menos o `ext_image_copy_capture_manager_v1`. O `zwlr_screencopy_manager_v1` cobre as miniaturas no lugar dele.

## Foreign-toplevel
O `wlrctl` (que fala `wlr-foreign-toplevel-management`) lista as janelas com `app_id` e título, e `focus`, `minimize`, `maximize` e `find state:minimized` funcionam. Exemplo:

```
firefox-esr: Debian -- The Universal Operating System — Mozilla Firefox
org.gtk.Demo4: GTK Demo
foot: foot
```

## A ponte
[`../bridge/labwc_bridge.py`](../bridge/labwc_bridge.py) é um esboço da ponte do Budgie:
- lê a cor de destaque do `~/.config/psito/settings.json`;
- reescreve o `themerc-override` (título ativo e bordas na cor de destaque, inativo no fundo `#12181B`, OSD do seletor);
- regenera a seção `<keyboard>` do `rc.xml` a partir de uma tabela que espelha a `shellBindings` (22 atalhos, os nativos e os de VM);
- manda o labwc recarregar com `labwc --reconfigure`.

De fora da sessão (pelo ssh), o `--reconfigure` não acha o labwc, porque ele usa o `LABWC_PID`, que só existe nos filhos do labwc. A ponte pega o pid pelo `pgrep`. Dentro do shell do Psito isso não acontece: o shell é filho do labwc.

**Testado ao vivo:** com o verde `#4CAF50` no `settings.json`, a ponte rodou, o labwc recarregou (mesmo pid) e a moldura do `foot` ficou verde.

**Mas só o `foot` mudou.** O `gtk4-demo` e o Firefox desenham a própria barra de título (decoração do lado do cliente) e não pedem a do compositor. O GTK no Wayland só usa decoração do lado do servidor pelo protocolo da KDE, que nem o labwc nem o Wayfire têm; o GTK 4 com libadwaita nunca usa. Ou seja, o tema da ponte vale para os apps que pedem moldura ao compositor (foot, Qt, Xwayland), e os apps GTK ficam com o tema GTK. Para combinar, a ponte também precisa gerar o tema GTK (cores do Adwaita por CSS em `~/.config/gtk-3.0` e `gtk-4.0`), como o Budgie faz. Isso vale também para os apps Flutter do Psito, que usam o embedder GTK.

O que é do shell (launcher e volume) vira `Execute` de um comando. Por enquanto o launcher abre o `foot` e o volume chama o `wpctl`; na etapa 4 isso passa a chamar o shell.

## Roteiro na janela do QEMU
Conferido pelo Francisco:
- o `waybar` aparece no topo, e uma janela maximizada para embaixo dele (zona exclusiva);
- snap com Alt+Shift+← e → e arrastando até a borda; maximizar com Alt+Shift+↑;
- Ctrl+Tab mostra o seletor de janelas com OSD; Alt+Shift+↓ minimiza e Ctrl+Alt+W fecha;
- a barra de tarefas do `waybar` ativa e minimiza as janelas pelo foreign-toplevel;

## Números (ao lado do Weston)
Duas rodadas com `spike/measure.sh labwc labwc`, sem o `waybar` e sem o Firefox (os mesmos clientes do Weston). As rodadas deram praticamente os mesmos números; a tabela mostra a segunda.

| Métrica | Weston | labwc |
|---|---|---|
| Memória própria do compositor (PSS anônimo), 0 / 5 clientes | 26,9 / 27,6 MB | 32,3 / 32,3 MB |
| PSS total do compositor, 0 clientes | 81,5 MB | 95,5 MB |
| CPU do compositor parado, 0 / 5 clientes | 0 / 0% | 0 / 0% |
| Entrega da tecla, mediana / p95 (1 cliente) | 0,56 / 6,9 ms | 0,54 / 0,84 ms |
| Tecla até o frame pronto, mediana / p95 (1 cliente) | 15,4 / 35,5 ms | 13,6 / 20,2 ms |
| fps do probe animado, 1 / 5 clientes | 53 / 33 | 60 / 59,4 |
| Tempo de frame do probe, p95, 1 / 5 clientes | 14,6 / 15,8 ms | 0,8 / 10,4 ms |

### Leitura
- **Parado de verdade:** 0% de CPU, como o Weston. Nada é desenhado se nada muda.
- **Memória estável:** 32,3 MB com 0 ou 5 clientes, uns 5 MB a mais que o Weston.
- **60 fps com tempo de frame abaixo de 1 ms,** como no Zenith. Isso confirma a correção do [`zenith.md`](zenith.md): os 15 ms por frame no Weston eram espera, não trabalho do probe.

## Para a decisão
- **A favor:**
  - todos os protocolos que o Psito usa, inclusive `ext-workspace` e `ext-foreign-toplevel-list`;
  - é a base do Budgie 10.10, o modelo que o Psito segue;
  - simples: a configuração é pequena e o comportamento é previsível.
- **Contra:**
  - **sem IPC:** os atalhos são uma tabela gerada pela ponte, e mudar um exige `--reconfigure`. O shell não é avisado de nada além do que os protocolos contam;
  - **sem animações de janela,** por política do projeto;
  - o modo da tela vem de fora (`wlr-randr` ou `zwlr_output_manager_v1`), não da configuração.
