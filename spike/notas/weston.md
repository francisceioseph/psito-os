# Weston (linha de base)

Weston 14.0.2 do Debian 13, `--backend=drm` com renderer GL (GLES 3.2 no VirGL), em 1440×900@59,9. Medido em 31/10/2026 com `spike/measure.sh weston weston`. Os números estão em [`../results/weston.csv`](../results/weston.csv).

## Como rodou
- Subiu de primeira no tty1, pela sessão do logind (`spike/session.sh weston`), sem root.
- Mostrou como janelas o probe (Flutter GTK), o `foot`, o `gtk4-demo` e o `weston-terminal`. Teclado e mouse chegam à janela com foco.
- O probe usa DMA-BUF (ver [`vm-gpu.md`](vm-gpu.md)).

## Números

| Métrica | 1 cliente | 5 clientes |
|---|---|---|
| Memória própria do Weston (PSS anônimo) | 27 MB | 27,6 MB |
| Memória dos clientes (PSS total) | 117 MB | 269 MB |
| Memória própria dos clientes (PSS anônimo) | 58 MB | 177 MB |
| CPU do Weston parado (30 s) | 0% | 0% |
| Latência de entrega da tecla, mediana / p95 | 0,56 / 6,9 ms | 0,53 / 0,72 ms |
| Tecla até o frame pronto no cliente, mediana / p95 | 15,4 / 35,5 ms | 14,0 / 21,0 ms |
| fps do probe animado | 53 | 33 |
| Tempo de frame do probe (build + raster), p95 | 14,6 ms | 15,8 ms |

Sem clientes, o Weston tem 26,9 MB de PSS anônimo e 81,5 MB de PSS total.

## Leitura
- **Entrega da tecla:** fica abaixo de 1 ms (do `uinput` até o probe, passando pelo libinput, pelo Weston, pelo GTK e pelo engine). Um p95 de 6,9 ms apareceu numa das rodadas e não se repetiu.
- **Tecla até o frame pronto:** de 14 a 15 ms, quase todos gastos no próprio probe (build e raster) e na espera do próximo frame.
- **fps:** (veja a correção em [`zenith.md`](zenith.md): os ~15 ms por frame do probe parecem ser espera do callback de frame do Weston, não trabalho.) Oscila entre rodadas, por volta de 30 ou de 53, porque o probe gasta cerca de 15 ms por frame no VirGL, no limite dos 16,7 ms de 60 Hz. Quando perde o vsync, cai para 30. O fps é limitado pelo cliente, não pelo Weston. Como o probe é o mesmo para todos os candidatos, a comparação continua valendo, mas é preciso repetir as rodadas (etapa 5).
- **Memória:** o PSS total do compositor cai quando abrem clientes (81 → 46 MB), porque as bibliotecas compartilhadas do Mesa se dividem entre mais processos. Para comparar compositores, use o PSS anônimo.
- **CPU parada:** zero, porque nada muda na tela. É a referência para ver se um compositor em Flutter desenha frames sem necessidade.

## O que não é medido
- O tempo entre o `rasterFinish` do cliente e o frame na tela. A composição e o page flip ficam de fora.
- **A tela do host:** o QEMU ainda copia o frame para a janela GTK do host. Esse custo é igual para todos os candidatos.
