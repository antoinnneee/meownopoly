#!/bin/bash
# logcat_android.sh
# Session de debug temps réel de l'app Meownopoly sur un device Android.
# Équivalent terminal de la console d'application de Qt Creator.
#
# Usage :
#   bash logcat_android.sh              # Tail live des qDebug de l'app
#   bash logcat_android.sh <IP>         # Même chose sur un device WiFi
#   bash logcat_android.sh <IP> -w      # Attend que l'app démarre, puis tail
#   bash logcat_android.sh <IP> -c      # Clear logcat avant tail
#   bash logcat_android.sh <IP> --crash # Filtre uniquement les crashes/fatals
#   bash logcat_android.sh <IP> --full  # Tout l'app + AndroidRuntime

set -euo pipefail

PACKAGE="org.qtproject.example.Meownopoly"
ADB="${ADB:-/usr/bin/adb}"
[[ -x "$ADB" ]] || ADB="$(command -v adb)"

# Premier arg : IP du device (optionnel si un seul device connecté)
IP=""
MODE="app"       # app|crash|full
WAIT=0
CLEAR=0

for arg in "$@"; do
    case "$arg" in
        --crash) MODE=crash ;;
        --full)  MODE=full ;;
        -w)      WAIT=1 ;;
        -c)      CLEAR=1 ;;
        -*)      echo "Flag inconnu : $arg" >&2 ; exit 1 ;;
        *)       IP="$arg" ;;
    esac
done

if [[ -n "$IP" ]]; then
    [[ "$IP" == *:* ]] || IP="$IP:5555"
    ADB_ARGS=(-s "$IP")
else
    ADB_ARGS=()
fi

[[ $CLEAR -eq 1 ]] && { "$ADB" "${ADB_ARGS[@]}" logcat -c; echo "logcat cleared"; }

# Attente du processus app si demandé
if [[ $WAIT -eq 1 ]]; then
    echo "En attente de $PACKAGE..."
    while true; do
        PID="$("$ADB" "${ADB_ARGS[@]}" shell pidof "$PACKAGE" 2>/dev/null | tr -d '\r\n')"
        [[ -n "$PID" ]] && break
        sleep 1
    done
    echo "PID=$PID — démarrage du tail"
else
    PID="$("$ADB" "${ADB_ARGS[@]}" shell pidof "$PACKAGE" 2>/dev/null | tr -d '\r\n' || true)"
fi

case "$MODE" in
    app)
        # Le filtrage --pid nécessite l'app lancée. Si pas de PID, on filtre
        # par tag sur les logs Qt typiques.
        if [[ -n "$PID" ]]; then
            echo "=== logcat --pid=$PID (Ctrl-C pour quitter) ==="
            exec "$ADB" "${ADB_ARGS[@]}" logcat --pid="$PID" -v threadtime
        else
            echo "=== App pas démarrée — filtre par tags Qt (-w pour attendre) ==="
            exec "$ADB" "${ADB_ARGS[@]}" logcat -v threadtime \
                Meownopoly:V QtCore:V QtQml:V QtQuick:V default:V \
                AndroidRuntime:E DEBUG:E '*:S'
        fi
        ;;
    crash)
        echo "=== Filtre crashes/fatals ==="
        exec "$ADB" "${ADB_ARGS[@]}" logcat -v threadtime \
            AndroidRuntime:E DEBUG:F libc:F '*:F' '*:S'
        ;;
    full)
        # App + erreurs système potentiellement liées (WindowManager, OpenGL, etc.)
        if [[ -n "$PID" ]]; then
            exec "$ADB" "${ADB_ARGS[@]}" logcat --pid="$PID" -v threadtime \
                AndroidRuntime:E OpenGL:V Surface:V WindowManager:V
        else
            exec "$ADB" "${ADB_ARGS[@]}" logcat -v threadtime
        fi
        ;;
esac
