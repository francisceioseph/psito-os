# O shell do Psito como cliente layer-shell

`spike/shell_client/`, testado em 31/10/2026 na VM do spike, sobre o labwc 0.8.3 e o Wayfire 0.9.0. Mostra a top bar, a dock, o launcher e os painéis reais do `system_shell`, com os serviços reais da fase 2.

## Como funciona
- **Um processo, um engine, uma view por superfície.** O embedder Linux do Flutter 3.47 cria várias `FlView` num engine (`fl_view_new_for_engine` e `fl_view_new_sized_to_content`), cada uma na sua `GtkWindow`, que o `gtk-layer-shell` transforma em superfície:

  | View | Camada | Tamanho | Zona exclusiva | Teclado |
  |---|---|---|---|---|
  | fundo (a implícita) | BACKGROUND | tela toda | -1 | nenhum |
  | top bar | TOP | largura toda, 40 px + 48 px para os tooltips | 40 px | nenhum |
  | dock | TOP | o do conteúdo, centrada na base com margem de 20 px | 80 px (mais a margem: a reserva de 100 px do `system_shell`) | nenhum |
  | sobreposição | OVERLAY | tela toda, só quando aberta | -1 | exclusivo com o launcher; sob demanda com os painéis |

- **O Dart (`lib/views.dart`) desenha as quatro views num isolate só,** com `ViewCollection`. Configurações, serviços, notificações e a lista de janelas são um objeto só (`ShellState`), sem IPC entre processos.
- **Regiões de input:**
  - a sobreposição exclui a faixa da top bar, e assim clicar na top bar troca de painel, como na fase 1;
  - a top bar exclui o espaço dos tooltips, e os cliques ali vão para as janelas.
- **Lista de janelas:**
  - o runner (`linux/runner/toplevels.cc`) liga o `zwlr_foreign_toplevel_manager_v1` no `wl_display` do GDK e manda as mudanças ao Dart pelo canal `psito/toplevels`;
  - o XML do protocolo vai em `linux/protocols/`, porque nenhum pacote do Debian traz.
- **Ícones:** o runner carrega pelo `GtkIconTheme` e devolve PNG (canal `psito/icons`).
- **Apps:** os `.desktop` de `/usr/share/applications` e do usuário. O id do arquivo bate com o `app_id` das janelas do Firefox, do `foot` e do GTK Demo.
- **Launcher por atalho do compositor:**
  - o shell assina `org.psito.Shell` na sessão (`ToggleLauncher`);
  - o Ctrl+Espaço do labwc (`rc.xml`) e o do Wayfire (plugin `command`) rodam o mesmo `gdbus call`;
  - nada no shell depende de um compositor específico.
- **No `system_shell`:**
  - a dock, o launcher e a busca passaram a receber um `AppEntry` (`lib/shell/app_entry.dart`) em vez do `PsitoApp`, porque um `.desktop` não tem `build()`;
  - o tema virou `psitoTheme(accent)` em `lib/app.dart`;
  - o comportamento do shell atual não mudou (132 testes).

Compilar e instalar: `spike/shell_client/build.sh`. O `autostart` do labwc e do Wayfire sobe o shell se ele estiver compilado; senão, o `waybar`.

## O que funcionou (conferido pelo Francisco, no labwc e no Wayfire)
- **Top bar:** rede, volume, bateria e relógio reais; os painéis abrem e trocam pela top bar; os tooltips aparecem inteiros.
- **Dock:** os fixados com os ícones do tema e o ponto dos apps abertos. O clique abre o app, ativa a janela ou minimiza a que está em foco.
- **O Firefox maximizado** para entre a top bar e a dock.
- **O launcher** abre pelo Ctrl+Espaço, a busca aceita o teclado (o `TextField` numa view que não é a implícita funcionou) e o app escolhido abre.
- **O papel de parede** vem das Configurações.
- **No Wayfire:** o mesmo binário funciona igual, só um pouco mais lento na percepção do Francisco. As animações do Wayfire continuam.

## Robustez
`kill -9` no shell não fecha as janelas nem derruba o labwc; subir o shell de novo traz tudo de volta. Ainda falta ele voltar sozinho (etapa 5).

## Números (labwc, shell parado, Firefox e `foot` abertos)
| | shell |
|---|---|
| PSS total | 141 MB |
| PSS anônimo (memória própria) | 98,6 MB |
| CPU parado (20 s) | 0,95% |

- **Memória:** é bem mais que o `waybar` e que o probe (uns 30 MB próprios). Podem ser as quatro views, cada uma com a sua superfície do Impeller, mais os serviços e o D-Bus. A medir na etapa 5, ao lado do `system_shell` no `flutter-pi`.
- **CPU parada:** quase zero. O que sobra deve ser o relógio da top bar.

## Problemas encontrados no caminho
- **Tooltips cortados:** eles são desenhados dentro da view da top bar, que tinha só 40 px. Agora a superfície tem 48 px a mais, transparentes, fora da zona exclusiva e da região de input.
- **Um `InkWell` sem `Material`:** o `DesktopBackground` tem um `InkWell`, e a view do fundo não tinha `Material`. O erro só apareceu no Wayfire, onde o ponteiro começa sobre o fundo.
- **`pkill -f` pelo ssh** mata o próprio comando do ssh, se o padrão aparece nele. Use `pgrep -x` ou um padrão que não esteja na linha de comando.

## Fica para a etapa 5
- toasts, OSD de volume e o Alt+Tab do Psito;
- o Super sozinho;
- o tema GTK gerado pela ponte;
- a unidade do systemd com `Restart`;
- as medições com 3 a 5 apps.
