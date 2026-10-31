# Zenith

[roscale/zenith](https://github.com/roscale/zenith), commit `aa7df0f`. O código é o de agosto de 2023 (`f38f553`); o commit de março de 2026 só mexe no README. Testado em 31/10/2026 na VM do spike. Os números estão em [`../results/zenith.csv`](../results/zenith.csv).

## Resultado curto
- **Funciona:** compila e mostra clientes Wayland, inclusive o probe (Flutter GTK), como janelas do shell em Flutter.
- **Não é estável na VM:** caiu com SIGSEGV nas duas rodadas de medição, aos 3 min 21 s e aos 2 min 36 s, sempre logo depois de um cliente novo conectar. Também não mostra o cursor.
- **Parado desde 2023:** para trazer ao wlroots e ao Flutter de 2026, falta portar o C++ e achar outra fonte para o engine.

## Como compilou
Do jeito que o autor compilava (o CI usava `debian:bookworm`):

| Peça | Versão | Como |
|---|---|---|
| wlroots | 0.15.1 | da fonte, em `/usr/local`, com Xwayland (o Zenith inclui `wlr/xwayland.h`) |
| Flutter | 3.10.6 | `~/flutter-3.10.6` |
| Engine | `cdbeda788a` | pré-compilado da Sony (`sony/flutter-embedded-linux`), baixado pelo Makefile |

Scripts: `spike/zenith/install.sh` (dependências) e `spike/zenith/build.sh` (bundle release).

Dois patches (`spike/patches/`):
- `zenith-clang19.patch`: `-Wno-vla-cxx-extension`, porque o clang 19 do Debian 13 acusa um array de tamanho variável e o Makefile usa `-Werror`;
- `zenith-mode.patch`: `ZENITH_MODE=1440x900` escolhe o modo da tela, porque o Zenith sempre usa o modo preferido e o do virtio-gpu é 640×480.

Para rodar: `spike/session.sh zenith`. O Zenith roda com `stdbuf -oL`, senão o `std::cout` dele fica preso no buffer e não chega ao journal. O log está em `sudo journalctl _COMM=zenith`.

## O que funcionou e o que não
- **Funcionou:**
  - modeset em 1440×900 pelo DRM, numa sessão do logind e sem root;
  - a interface desktop dele: fundo branco (sem papel de parede) e as janelas por cima;
  - os quatro clientes conectam; o probe aparece e recebe as 200 teclas do `uinput`;
  - o probe aberto por último fica com o foco do teclado.
- **Não funcionou:**
  - **tela preta na primeira partida:** depois de um evento de hotplug do DRM, aos 36 s, a tela não saiu do preto. Nas partidas seguintes apareceu normal;
  - **sem cursor:** o wlroots cai no cursor por software (*"Direct scan-out disabled by software cursor"*), e ele não aparece na tela;
  - **queda:**
    - a partir de um certo momento, o commit da saída falha em laço (*"Basic output test failed"*, de 20 a 60 mil vezes em 20 s), e o Zenith tenta de novo a cada 1 ms;
    - logo depois de um cliente novo conectar, ele cai com SIGSEGV;
    - aconteceu nas duas rodadas, em pontos diferentes: antes do fps com 1 cliente, e ao abrir os 4 clientes do cenário de 5;
  - não investiguei a causa: o limite da etapa é não consertar o projeto dos outros.

## Números (ao lado do Weston)

| Métrica | Weston | Zenith |
|---|---|---|
| Memória própria do compositor (PSS anônimo), 0 / 5 clientes | 26,9 / 27,6 MB | 37 / 42 MB |
| PSS total do compositor, 0 clientes | 81,5 MB | 110 MB |
| CPU do compositor parado, 0 / 5 clientes | 0 / 0% | 1 a 4% / 1 a 4% |
| Entrega da tecla, mediana / p95 (1 cliente) | 0,56 / 6,9 ms | 0,86 / 1,3 ms |
| Tecla até o frame pronto, mediana / p95 (1 cliente) | 15,4 / 35,5 ms | 13,7 / 20,5 ms |
| fps do probe animado (1 cliente) | 53 (oscila 30 a 53) | 60 |
| Tempo de frame do probe, p95 (1 cliente) | 14,6 ms | 0,64 ms |
| Latência e fps com 5 clientes | medidos | **caiu antes** |

### Leitura
- **Memória:** o Zenith carrega o engine do Flutter e o app Dart no mesmo processo, e mesmo assim gasta só uns 10 a 15 MB a mais que o Weston.
- **CPU parada:** o Zenith nunca fica parado. A cada vsync ele avisa o Flutter, manda `frame_done` a todas as janelas visíveis e entrega um buffer à saída, mesmo sem nada mudar. Isso gasta CPU e, num notebook, bateria.
- **O probe roda a 60 fps no Zenith e a 30 a 53 no Weston,** com tempo de frame de 0,6 ms contra 15 ms. A explicação provável:
  - o `frame_done` a cada vsync deixa o cliente desenhar sem esperar;
  - no Weston, o `eglSwapBuffers` do GTK espera o callback de frame, e essa espera entra no tempo de raster que o probe mede;
  - ou seja, os 15 ms do Weston eram espera, não trabalho. **Isso corrige a leitura do [`weston.md`](weston.md).** Ainda é uma hipótese, a conferir com o protótipo próprio.

## Arquitetura (lida no código)
- **C++ com wlroots e um embedder do Flutter próprio.** O shell inteiro é um app Flutter que roda dentro do compositor.
- **Janelas como textura:**
  - cada surface vira uma textura externa (`FlutterEngineRegisterExternalTexture`);
  - a cada commit do cliente, o Zenith espera o fence do buffer (DMA-BUF ou fence nativo do EGL), marca o frame disponível e manda `commit_surface` ao Dart pelo canal `platform`, com a geometria, as subsurfaces, o título e o `app_id`;
  - no callback de textura externa, o Flutter recebe o nome da textura GLES que o wlroots criou do buffer do cliente, sem cópia.
- **Dart decide quase tudo:**
  - o teclado vai primeiro ao Flutter (canal `flutter/keyevent`), e o que ele não trata segue ao cliente; Alt+Esc fecha o compositor;
  - o ponteiro vai inteiro ao Flutter, que escolhe a janela e devolve `pointer_hover`, `mouse_button_event` e outros pelo canal `platform`;
  - o foco, mover, redimensionar, maximizar, fechar e mostrar ou esconder ficam no Dart (`activate_window`, `resize_window`, `interactive_move`…), e o C++ só executa.
- **Os canais e o widget de janela** são o contrato que o Psito teria que reaproveitar (ou reescrever). O resto do `lib/` é a interface dele (desktop e celular, Riverpod), que o Psito trocaria pela sua.
- **Licença GPL-2.0+.**

## Trocar a UI do Zenith pela do Psito
- **O que se aproveita:**
  - o modelo é o que o roadmap quer: o `DesktopScreen` do Psito entraria no lugar do `lib/ui/` do Zenith;
  - o `PsitoWindow` passaria a desenhar um `Texture(textureId)` com o conteúdo do cliente, em vez do widget do app interno;
  - o `WindowManager` do Psito já decide foco, z-order e snap em Dart, que é exatamente o lado que o Zenith deixa para o Dart.
- **O que pesa:**
  - **versão do Flutter:** o Psito usa o Flutter 3.47 e o Zenith funciona no 3.10;
  - **o C++ preso ao wlroots 0.15;**
  - **estabilidade:** os SIGSEGV teriam que ser entendidos antes de construir em cima;
  - **licença:** um fork faria o Psito ser GPL.

## Custo de trazer para 2026 (só tentei compilar, sem consertar)
- **C++ contra o wlroots 0.18 do Debian 13:**
  - 250 erros em 19 dos 35 arquivos (`clang++ -fsyntax-only`, contando os erros em cascata);
  - os maiores são `touch.cpp` (36), `zenith_surface.cpp` (30), `pointer.cpp` (27) e `output.cpp` (23);
  - são as mudanças de API de 0.15 para 0.18: backend com sessão, `wlr_output_state`, versões nos `*_create` e eventos de input.
  - Também depende de estruturas internas do renderer GLES2 (`wlr_gles2_buffer`), que não são API pública.
- **Dart com o Flutter 3.47.4:**
  - as dependências resolvem pelo `pubspec.lock`;
  - o `flutter analyze` acusa 1 erro (um getter que falta implementar, `ScrollContext.devicePixelRatio`) e 56 avisos. É o lado barato.
- **Engine:**
  - a Sony parou na 3.32.8 (julho de 2025) e não há release para o engine do 3.47.4 (`06a2e2a110`);
  - o Flutter publica um `linux-x64-embedder.zip` oficial para esse engine, que acho que é só debug;
  - para release, os engines de embedder que o `flutterpi_tool` já baixa para o Psito são um caminho provável. Não testei.
