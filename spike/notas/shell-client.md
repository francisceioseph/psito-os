# O shell do Psito como cliente layer-shell

`spike/shell_client/`, testado em 31/10/2026 na VM do spike, sobre o labwc 0.8.3 e o Wayfire 0.9.0. Mostra a top bar, a dock, o launcher e os painéis reais do `system_shell`, com os serviços reais da fase 2.

## Como funciona
- **Um processo, um engine, uma view por superfície.** O embedder Linux do Flutter 3.47 cria várias `FlView` num engine (`fl_view_new_for_engine`; a dock usava `fl_view_new_sized_to_content` até a etapa 5, ver abaixo), cada uma na sua `GtkWindow`, que o `gtk-layer-shell` transforma em superfície:

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
`kill -9` no shell não fecha as janelas nem derruba o labwc; subir o shell de novo traz tudo de volta. Na etapa 5 ele passou a voltar sozinho (ver abaixo).

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

## Etapa 5: uso diário e robustez (31/10/2026)
### A ponte em Dart (`lib/bridge/`)
- **Uma tabela só:** o `bindings.dart` converte a `shellBindings` do `system_shell` para os nomes do labwc (`C-A-w`) e do Wayfire (`<ctrl> <alt> KEY_W`), mais o Super sozinho para o launcher. O `labwc_bridge.py` saiu.
- **Quem faz cada ação:**
  - fechar, maximizar, snap e minimizar ficam com o compositor;
  - launcher, Alt+Tab e volume viram um `gdbus call … org.psito.Shell.Run '<ação>'`.
- **labwc** (`LABWC_PID` no ambiente): a ponte reescreve a seção `<keyboard>` do `rc.xml` e o `themerc-override` e roda o `labwc --reconfigure`.
- **Wayfire** (`WAYFIRE_SOCKET`): `wayfire/set-config-options` pelo IPC, sem tocar no `wayfire.ini`.
  - As listas do plugin `command` vão como dicionário: `{"psito_launcher": {"command": …, "binding": …}}`. Como lista, o Wayfire recusa.
  - O `<super>` sozinho funciona nos `bindings` comuns, mas não nos `release_bindings`.
- **Tema GTK:** o `gtk.css` (cores nomeadas do Adwaita e do GTK 3) e o `settings.ini` escuro, nos dois GTK. Um arquivo sem o cabeçalho da ponte é do usuário e fica como está.
- **O bug do primeiro teste:** o comentário do topo do `rc.xml` citava `<keyboard>`, e a expressão regular casou a partir dali. Ela quebrou o XML, e o labwc ficou sem nenhum atalho. Agora só vale a tag no começo da linha, e há um teste para isso.

### Alt+Tab
- **O fluxo:**
  - o primeiro Ctrl+Tab abre o seletor do `system_shell` sobre as janelas do foreign-toplevel, com a sobreposição pegando o teclado;
  - os seguintes chegam como `Run` e avançam;
  - soltar o Ctrl ativa a janela escolhida.
- **O risco não aconteceu:** o Ctrl foi apertado antes de a sobreposição ter o teclado, mas o Flutter recebe o key-up dele mesmo assim. O plano B não foi preciso.
- **O labwc consome o Ctrl+Tab** com a sobreposição aberta, então o caminho do Tab pelo Flutter fica de reserva.

### Notificações, toasts e OSD
- **O servidor:** o shell assina `org.freedesktop.Notifications`. O `notify-send` vira toast, com o ícone do app pelo `desktop-entry` ou pelo nome, e o corpo sai sem as marcações.
- **O OSD de volume** aparece acima da dock.
- **As duas superfícies novas** existem só enquanto têm algo na tela.

### A dock sumiu: as views dimensionadas pelo conteúdo não servem
- **O sintoma:** com o runner da etapa 5, a dock não aparecia.
  - Pelo `WAYLAND_DEBUG`, a superfície dela ficava nos 200×200 do primeiro configure e nunca recebia um buffer.
  - O código do embedder (`fl_view_renderer.cc`, 3.47.4) explica: quando o frame tem outro tamanho, ele pede o tamanho novo à `GtkWindow` e só desenha quando os dois batem. Sobre o layer-shell, a janela não muda de tamanho.
  - Na etapa 4 funcionou, provavelmente por sorte de ordem. Não deu para reproduzir.
- **A troca:** a dock, os toasts e o OSD agora são views comuns.
  - O Dart mede o conteúdo sem limite (`OverflowBox` com o `SizeReporter`) e manda `resize` pelo canal `psito/surfaces`.
  - O runner faz `gtk_widget_set_size_request` e `gtk_window_resize`, e a superfície acompanha.
- **Na investigação:** um `git worktree` da etapa 4 deixou fontes com data mais nova na VM, e o CMake parou de recompilar o runner. Foi preciso apagar o `build/linux` da VM.

### O shell como unidade do systemd
- **A unidade:** `psito-shell.service` no systemd do usuário, com `Restart=always`, `RestartSec=1` e um limite de 5 tentativas em 30 s.
- **Quem sobe:** o `psito-shell-start`, chamado pelo `autostart` do labwc e do Wayfire.
  - Ele tira o `LABWC_PID` e o `WAYFIRE_SOCKET` da sessão anterior e importa os desta.
  - Sem o shell compilado, sobe o `waybar`.
- **`kill -9` no shell:** ele volta em 1,0 s (o `RestartSec`). A dock mostra as janelas de novo e os atalhos continuam. O histórico de notificações se perde.
- **`kill -9` no Firefox:** o shell continua (mesmo pid), e o ponto do Firefox some da dock.

### Números (labwc, `spike/measure-shell.sh`, `results/shell.csv`)
| | memória própria (anônima) | CPU parado |
|---|---|---|
| probe (1 view, sem serviços) | 59,4 MB | |
| shell só com o fundo (1 view) | 72,7 MB | 0,15% |
| fundo e top bar (2) | 82,0 MB | 0,9% |
| as 4 da etapa 4 | 95,8 MB | 1,2% |
| as 6 (toasts e OSD escondidos) | 94,6 MB | 1,2% |
| shell com 0 / 3 / 5 apps | 101,8 / 102,0 / 100,4 MB | 0,9 / 1,15 / 1,05% |
| labwc com 0 / 3 / 5 apps | 32,1 MB | 0,2 a 0,25% |

- **De onde vêm os ~100 MB:**
  - a base do Flutter com o GTK já é de 59 MB (o probe);
  - os serviços, o D-Bus e o código do shell somam uns 13 MB;
  - cada view visível custa de 5 a 10 MB;
  - os toasts e o OSD escondidos não custam nada visível.
- **Pelo `smaps`, comparado com o probe:**
  - a memória anônima sem nome (o heap do Dart e os buffers do Impeller) vai de 32 para 55 MB;
  - o heap do C (o GTK, as janelas, o D-Bus), de 18 para 30 MB.
- **A memória não cresce com os apps abertos.**
- **CPU parado:** cerca de 1% com a top bar e 0,15% só com o fundo. Algo na top bar redesenha mesmo sem os segundos no relógio, e isso fica para investigar.
- **Um atalho do shell** custa um `gdbus call`: 6,2 ms de mediana e 7,3 ms de p95. Não se sente no Alt+Tab.
- **Correção na bancada:** o `awk` do host, em pt_BR, lia "1.20" como 1. O `column` do `measure.sh` também tinha esse erro, então as CPUs parciais das etapas 1 a 3 podem ter saído arredondadas para baixo.

## Fica para depois
- toasts com ações além do clique (botões), e o `expire_timeout` de cada notificação;
- a CPU da top bar parada;
- o Firefox: as notificações dele e o modo escuro pelo portal.
