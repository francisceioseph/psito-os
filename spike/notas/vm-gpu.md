# GPU e Wayland na VM do spike

Conferido em 31/10/2026 na VM `psito-spike` (Debian 13, QEMU com `virtio-vga-gl`, 4 vCPUs, 3 GB).

## Resposta curta
**O caminho sem cópia funciona na VM.**
- O Mesa do VirGL expõe a importação de DMA-BUF.
- O probe (Flutter GTK) entrega os frames ao Weston por `zwp_linux_dmabuf_v1`.

Por isso os candidatos podem importar as janelas como textura EGL, como no hardware real, e os números da VM valem para comparar os candidatos. A diferença para o hardware real fica no custo do VirGL, que encaminha cada chamada GL para a GPU do host.

## Mesa e EGL
- Mesa 25.0.7 (`libegl-mesa0 25.0.7-2+deb13u1`), EGL 1.5.
- Renderer: `virgl (AMD Radeon Graphics (radeonsi, renoir…))`, ou seja, a GPU AMD do host por trás do VirGL.
- OpenGL 4.3 core e OpenGL ES 3.2 (este último é o que o Weston usa).
- Extensões por plataforma (`eglinfo -p …`):

  | Extensão | gbm | surfaceless |
  |---|---|---|
  | `EGL_EXT_image_dma_buf_import` | sim | sim |
  | `EGL_EXT_image_dma_buf_import_modifiers` | sim | sim |
  | `EGL_MESA_image_dma_buf_export` | sim | sim |
  | `EGL_WL_bind_wayland_display` | sim | sim |
  | `EGL_EXT_buffer_age` | sim | não |

## DRM
- Modesetting atômico: sim. Page flip assíncrono atômico: não.
- O modo "preferido" do virtio-gpu é 640×480. O `weston.ini` do spike fixa 1440×900@59,9, que cabe na janela do QEMU. Os outros candidatos precisam usar o mesmo modo.

## Wayland (Weston 14.0.2)
- Globais relevantes:
  - `zwp_linux_dmabuf_v1` v5, com feedback por surface;
  - `zwp_linux_explicit_synchronization_v1` v2;
  - `wp_presentation`, `wp_viewporter`, `xdg_wm_base` v5 e `zwp_text_input_manager_v1`.
- Probe com `WAYLAND_DEBUG=1`:
  - o probe chama `create_params`/`add`/`create_immed` do `zwp_linux_buffer_params_v1`, ou seja, o frame vai por DMA-BUF;
  - ele também usa um `wl_shm_pool`, provavelmente para o cursor.

## Versões no Debian 13 (para a etapa 4)
- wlroots: só a 0.18 (`libwlroots-0.18-dev`).
- Rust: `rustc`/`cargo` 1.85.1 no apt. Não estão instalados.
- Flutter 3.47.4 instalado em `/home/psito/flutter`, o mesmo do host.

## Detalhes da bancada
- **Onde fica o log do compositor:** o `psito-spike.service` abre uma sessão do logind, e o processo vai para o `session-N.scope` do usuário. Por isso o log não aparece em `journalctl -u psito-spike`; use `sudo journalctl _COMM=weston`.
- **Permissão para medir:** o `smaps_rollup` do compositor só pode ser lido com sudo, porque o processo não é dumpable.
