#!/bin/bash
# Mede os apps do Psito na VM (fase 4, etapa 6) e grava um CSV:
# - a memória de 3 apps abertos juntos, com o runtime compartilhado (os pacotes)
#   e com os bundles separados (cada um com o seu libflutter, em
#   ~/psito-src/apps/<id>/build/), os dois sem sandbox para isolar o runtime;
# - o que o sandbox custa por app (o bwrap e o xdg-dbus-proxy);
# - o tempo do comando até o primeiro quadro (o "🦜 primeiro quadro" do
#   runtime), com o sandbox e sem ele.
# Uso (do host, com a sessão rodando e um build de release):
#   ssh -p 2222 psito@localhost 'bash -s' < tools/measure-apps.sh
# RUNS (padrão 5) vezes cada abertura; OUT (padrão /tmp/fase4-apps.csv).
set -e

export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
APPS=(settings clock calculator)
RUNS="${RUNS:-5}"
OUT="${OUT:-/tmp/fase4-apps.csv}"
SETTLE=5

perms() { sed -n 's/^X-Psito-Permissions=//p' "/usr/share/applications/org.psito.$1.desktop"; }

# Abre o app como o shell abre (systemd-run e systemd-cat) e imprime a unidade.
# Modos: sandbox, direto (o pacote sem sandbox) e bundle (o build separado).
open_app() {
    local mode="$1" id="$2" exe="/usr/lib/psito/apps/org.psito.$2/psito_$2" cmd
    local unit="app-psito-org.psito.$id-$(printf %x $((RANDOM * 32768 + RANDOM))).scope"
    case "$mode" in
        sandbox) cmd=(/usr/local/bin/psito-sandbox --app "org.psito.$id" --permissions "$(perms "$id")" -- "$exe") ;;
        direto) cmd=("$exe") ;;
        bundle) cmd=("$HOME/psito-src/apps/$id/build/linux/x64/release/bundle/psito_$id") ;;
    esac
    systemd-run --user --scope --collect --quiet --unit="$unit" -- \
        systemd-cat --identifier="org.psito.$id" "${cmd[@]}" >/dev/null 2>&1 &
    echo "$unit"
}

procs() { cat "/sys/fs/cgroup$(systemctl --user show -P ControlGroup "$1")/cgroup.procs" 2>/dev/null; }
app_pid() { local p; for p in $(procs "$1"); do [[ "$(cat /proc/$p/comm)" == psito_* ]] && echo "$p"; done; }
rollup() { awk -v k="$2:" '$1 == k { print $2 }' "/proc/$1/smaps_rollup"; }
flutter_pss() { awk '/libflutter_linux_gtk/ { on = 1; next } /^[0-9a-f]+-/ { on = 0 } on && $1 == "Pss:" { s += $2 } END { print s + 0 }' "/proc/$1/smaps"; }
close_all() { systemctl --user stop 'app-psito-org.psito.*' 2>/dev/null || true; sleep 1; }

echo "tipo,modo,app,rodada,valor1,valor2,valor3,valor4" > "$OUT"
close_all

echo "📏 Memória (${APPS[*]} juntos, ${SETTLE}s depois de abrir)"
for mode in direto bundle sandbox; do
    units=()
    for id in "${APPS[@]}"; do units+=("$(open_app "$mode" "$id")"); done
    sleep "$SETTLE"
    total=0
    for i in "${!APPS[@]}"; do
        pid="$(app_pid "${units[$i]}")"
        [ -n "$pid" ] || { echo "❌ ${APPS[$i]} não abriu em $mode" >&2; continue; }
        pss="$(rollup "$pid" Pss)" rss="$(rollup "$pid" Rss)" fl="$(flutter_pss "$pid")"
        extra=0
        for p in $(procs "${units[$i]}"); do
            [ "$p" = "$pid" ] || extra=$((extra + $(rollup "$p" Rss)))
        done
        echo "mem,$mode,${APPS[$i]},1,$pss,$rss,$fl,$extra" >> "$OUT"
        total=$((total + pss))
    done
    echo "   $mode: Pss dos apps somado = $((total / 1024)) MB"
    close_all
done

echo "⏱️  Tempo até o primeiro quadro ($RUNS vezes)"
for mode in sandbox direto; do
    for id in "${APPS[@]}"; do
        times=()
        for run in $(seq "$RUNS"); do
            start="$(date +%s%3N)"
            unit="$(open_app "$mode" "$id")"
            frame=
            for _ in $(seq 200); do
                frame="$(journalctl --user -u "$unit" -o cat 2>/dev/null |
                    sed -n 's/.*primeiro quadro: \([0-9]*\).*/\1/p' | head -n 1)"
                [ -n "$frame" ] && break
                sleep 0.1
            done
            close_all
            [ -n "$frame" ] || { echo "❌ $id ($mode) sem primeiro quadro" >&2; continue; }
            echo "start,$mode,$id,$run,$((frame - start)),,," >> "$OUT"
            times+=($((frame - start)))
        done
        median="$(printf '%s\n' "${times[@]}" | sort -n | awk '{ a[NR] = $1 } END { print a[int((NR + 1) / 2)] }')"
        echo "   $mode $id: mediana ${median} ms (${times[*]})"
    done
done
echo "✅ $OUT"
