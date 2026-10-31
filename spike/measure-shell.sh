#!/bin/bash
# Mede o shell do Psito (shell/) rodando no labwc da VM do spike e
# grava spike/results/shell.csv.
# Uso: spike/session.sh labwc && spike/measure-shell.sh
# Cenários:
#   - o custo de cada view: o shell com 1, 2, 4 e 6 superfícies
#     (PSITO_SURFACES), parado, e o probe (uma view, sem serviços) de base;
#   - o shell e o labwc parados com 0, 3 e 5 apps;
#   - de onde vem a memória do shell (smaps por tipo de mapeamento);
#   - quanto custa um atalho do shell: o gdbus call que o compositor roda.
set -e

cd "$(dirname "$0")"

VM_PORT="${VM_PORT:-2223}"
export VM_PORT
OUT="results/shell.csv"
PROBE=/home/psito/probe/probe
IDLE_SECS="${IDLE_SECS:-20}"

vm() { ssh -p "$VM_PORT" psito@localhost "$@"; }
metric() { echo "$1,$2" | tee -a "$OUT"; }
# Coluna das linhas do sample.sh: 3 PSS, 4 anônimo, 5 CPU
column() { LC_ALL=C awk -F, -v c="$1" '{s += $c} END {print s + 0}'; }
shell_pid() { vm "systemctl --user show -p MainPID --value psito-shell"; }
close_apps() {
    vm "pkill -f '^$PROBE' ; pkill -x foot ; pkill -x gtk4-demo ; pkill -x firefox-esr ; true"
    sleep 3
}
# Sobe o shell com só as superfícies pedidas (vazio: todas)
restart_shell() {
    if [ -n "$1" ]; then
        vm "systemctl --user set-environment PSITO_SURFACES=$1"
    else
        vm "systemctl --user unset-environment PSITO_SURFACES"
    fi
    vm "systemctl --user restart psito-shell"
    sleep 12
}

comp=$(vm "pgrep -o -x labwc") || {
    echo "❌ O labwc não está rodando (spike/session.sh labwc)."
    exit 1
}
rsync -az -e "ssh -p $VM_PORT" tools/ psito@localhost:/tmp/spike/tools/
close_apps
echo "metrica,valor" > "$OUT"
metric compositor labwc
metric data "$(date -Iseconds)"

echo "🧩 Custo de cada view..."
for surfaces in background background,topbar background,topbar,dock,overlay ""; do
    restart_shell "$surfaces"
    n=$(( $(echo "${surfaces:-a,b,c,d,e,f}" | tr ',' '\n' | wc -l) ))
    row=$(vm "/tmp/spike/tools/sample.sh $IDLE_SECS $(shell_pid)")
    metric "shell_pss_kib_views_$n" "$(echo "$row" | column 3)"
    metric "shell_anon_kib_views_$n" "$(echo "$row" | column 4)"
    metric "shell_cpu_parado_pct_views_$n" "$(echo "$row" | column 5)"
done

echo "🔬 smaps do shell, por tipo..."
vm "python3 /tmp/spike/tools/smaps_by_kind.py $(shell_pid)" |
    while IFS=, read -r kind pss anon; do
        metric "shell_smaps_${kind}_pss_kib" "$pss"
        metric "shell_smaps_${kind}_anon_kib" "$anon"
    done

echo "🐦 O probe de base (uma view, sem serviços)..."
probe=$(./client.sh "$PROBE")
sleep 6
row=$(vm "/tmp/spike/tools/sample.sh $IDLE_SECS $probe")
metric probe_pss_kib "$(echo "$row" | column 3)"
metric probe_anon_kib "$(echo "$row" | column 4)"
vm "python3 /tmp/spike/tools/smaps_by_kind.py $probe" |
    while IFS=, read -r kind pss anon; do
        metric "probe_smaps_${kind}_anon_kib" "$anon"
    done
close_apps

echo "📏 O shell e o labwc com 0, 3 e 5 apps..."
apps=()
for n in 0 3 5; do
    while [ "${#apps[@]}" -lt "$n" ]; do
        case "${#apps[@]}" in
            0) apps+=("$(./client.sh foot)") ;;
            1) apps+=("$(./client.sh gtk4-demo)") ;;
            2) apps+=("$(./client.sh firefox-esr)") ; sleep 10 ;;
            *) apps+=("$(./client.sh foot)") ;;
        esac
        sleep 3
    done
    sleep 5
    rows=$(vm "sudo /tmp/spike/tools/sample.sh $IDLE_SECS $(shell_pid) $comp")
    metric "shell_pss_kib_apps_$n" "$(echo "$rows" | sed -n 1p | column 3)"
    metric "shell_anon_kib_apps_$n" "$(echo "$rows" | sed -n 1p | column 4)"
    metric "shell_cpu_parado_pct_apps_$n" "$(echo "$rows" | sed -n 1p | column 5)"
    metric "labwc_anon_kib_apps_$n" "$(echo "$rows" | sed -n 2p | column 4)"
    metric "labwc_cpu_parado_pct_apps_$n" "$(echo "$rows" | sed -n 2p | column 5)"
done
close_apps

echo "⌨️  Custo do gdbus call de um atalho..."
ms=$(vm 'python3 - <<EOF
import statistics, subprocess, time
times = []
for _ in range(20):
    t = time.monotonic()
    subprocess.run(["gdbus", "call", "--session", "--dest", "org.psito.Shell",
                    "--object-path", "/org/psito/Shell", "--method",
                    "org.freedesktop.DBus.Peer.Ping"], check=True,
                   stdout=subprocess.DEVNULL)
    times.append((time.monotonic() - t) * 1000)
times.sort()
print(f"{statistics.median(times):.1f},{times[int(len(times) * 0.95) - 1]:.1f}")
EOF')
metric gdbus_call_mediana_ms "${ms%,*}"
metric gdbus_call_p95_ms "${ms#*,}"

echo "✅ $OUT"
