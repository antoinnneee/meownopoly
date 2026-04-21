#!/bin/bash
# meow_deploy.sh
# Script unifié de déploiement Meownopoly vers Android (USB ou WiFi).
# Détecte automatiquement le mode de transport, reconnecte si besoin,
# rebuild l'APK si il manque, uninstall en cas de conflit de signature,
# installe, lance l'app, et peut suivre les logs.
#
# Usage :
#   meow_deploy.sh                        # auto : premier device dispo, build si APK absent
#   meow_deploy.sh --wifi [IP]            # force WiFi (reconnecte sur dernière IP si omise)
#   meow_deploy.sh --usb                  # force USB
#   meow_deploy.sh --rebuild              # force rebuild APK (clean signing)
#   meow_deploy.sh --no-install           # skip install, juste launch l'app déjà installée
#   meow_deploy.sh --logcat               # après install + launch, tail logcat filtré
#   meow_deploy.sh --uninstall            # uninstall puis exit
#   meow_deploy.sh --pair <IP:PORT> <CODE> # 1er pairage Android 11+ wireless debugging
#   meow_deploy.sh --pair-usb             # active TCP/IP via USB puis bascule WiFi

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$(dirname "$PROJECT_DIR")/build-android"
TARGET_NAME="Meownopoly"
PACKAGE_NAME="org.qtproject.example.Meownopoly"
LAST_DEVICE_FILE="$HOME/.meownopoly_last_device"
WIFI_PORT="${ADB_WIFI_PORT:-5555}"
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Source env si existe (BOX64_LD_LIBRARY_PATH, QEMU_LD_PREFIX, etc.)
[[ -f "$HOME/.meownopoly_android.env" ]] && source "$HOME/.meownopoly_android.env"

# adb natif aarch64 (Fedora android-tools)
if [[ -x /usr/bin/adb ]]; then
    ADB=/usr/bin/adb
else
    ADB="$(command -v adb)" || { echo "adb introuvable — 'sudo dnf install android-tools'"; exit 1; }
fi

# --- Parse args -------------------------------------------------------------
MODE=auto                 # auto | wifi | usb
WIFI_IP=""
REBUILD=0
NO_INSTALL=0
DO_LOGCAT=0
DO_UNINSTALL=0
DO_PAIR=""
PAIR_CODE=""
DO_PAIR_USB=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --wifi)      MODE=wifi; shift; [[ $# -gt 0 && "$1" != --* ]] && { WIFI_IP="$1"; shift; } ;;
        --usb)       MODE=usb; shift ;;
        --rebuild)   REBUILD=1; shift ;;
        --no-install) NO_INSTALL=1; shift ;;
        --logcat)    DO_LOGCAT=1; shift ;;
        --uninstall) DO_UNINSTALL=1; shift ;;
        --pair)      DO_PAIR="$2"; PAIR_CODE="$3"; shift 3 ;;
        --pair-usb)  DO_PAIR_USB=1; shift ;;
        -h|--help)   sed -n '2,/^#$/p' "$0" | sed 's|^# \?||'; exit 0 ;;
        *)           echo "Arg inconnu : $1" >&2 ; exit 1 ;;
    esac
done

# --- Helpers ----------------------------------------------------------------

# Pair Android 11+ Wireless Debugging
cmd_pair() {
    local addr="$1" code="$2"
    echo "=== Pairage Android 11+ $addr ==="
    "$ADB" pair "$addr" "$code"
    echo "Pairage OK. Note l'IP:PORT principale (différente du pairage) pour deploy."
}

# Active TCP/IP via USB puis bascule WiFi
cmd_pair_usb() {
    echo "=== Activation TCP/IP via USB ==="
    local usb_dev
    usb_dev="$("$ADB" devices | awk 'NR>1 && /device$/ {print $1}' | grep -v ':' | head -1)"
    [[ -z "$usb_dev" ]] && { echo "Aucun device USB détecté"; exit 1; }
    local ip
    ip="$("$ADB" -s "$usb_dev" shell ip route 2>/dev/null | awk '/wlan0/ {for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}' | head -1)"
    [[ -z "$ip" ]] && ip="$("$ADB" -s "$usb_dev" shell ip -f inet addr show wlan0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -1)"
    [[ -z "$ip" ]] && { echo "Pas d'IP WiFi détectée — connecte le téléphone au WiFi"; exit 1; }
    echo "IP WiFi : $ip"
    "$ADB" -s "$usb_dev" tcpip "$WIFI_PORT"
    sleep 2
    "$ADB" connect "$ip:$WIFI_PORT"
    echo "$ip:$WIFI_PORT" > "$LAST_DEVICE_FILE"
    echo "TCP/IP OK. Débranche l'USB, re-lance : $0"
}

# Détecte un device connecté et remplit TARGET_DEVICE
select_device() {
    local devices wifi_devs usb_devs
    devices="$("$ADB" devices | awk 'NR>1 && /device$/ {print $1}')"

    wifi_devs="$(echo "$devices" | grep ':' || true)"
    usb_devs="$(echo "$devices" | grep -v ':' | grep -v '^$' || true)"

    case "$MODE" in
        wifi)
            if [[ -n "$WIFI_IP" ]]; then
                [[ "$WIFI_IP" == *:* ]] || WIFI_IP="$WIFI_IP:$WIFI_PORT"
                echo "Connexion à $WIFI_IP..."
                "$ADB" connect "$WIFI_IP" >/dev/null
                TARGET_DEVICE="$WIFI_IP"
            elif [[ -f "$LAST_DEVICE_FILE" ]]; then
                local last
                last="$(cat "$LAST_DEVICE_FILE")"
                echo "Reconnexion à $last (dernier device WiFi)..."
                "$ADB" connect "$last" >/dev/null
                TARGET_DEVICE="$last"
            elif [[ -n "$wifi_devs" ]]; then
                TARGET_DEVICE="$(echo "$wifi_devs" | head -1)"
            else
                echo "Aucun device WiFi. Utilise : $0 --pair-usb (puis USB) ou --pair <IP:PORT> <CODE>"
                exit 1
            fi
            ;;
        usb)
            [[ -z "$usb_devs" ]] && { echo "Aucun device USB"; exit 1; }
            TARGET_DEVICE="$(echo "$usb_devs" | head -1)"
            ;;
        auto)
            if [[ -n "$usb_devs" ]]; then
                TARGET_DEVICE="$(echo "$usb_devs" | head -1)"
                echo "Device USB détecté : $TARGET_DEVICE"
            elif [[ -n "$wifi_devs" ]]; then
                TARGET_DEVICE="$(echo "$wifi_devs" | head -1)"
                echo "Device WiFi déjà connecté : $TARGET_DEVICE"
            elif [[ -f "$LAST_DEVICE_FILE" ]]; then
                local last
                last="$(cat "$LAST_DEVICE_FILE")"
                echo "Tentative reconnexion WiFi $last..."
                "$ADB" connect "$last" >/dev/null 2>&1 || true
                if "$ADB" devices | grep -q "${last}.*device\$"; then
                    TARGET_DEVICE="$last"
                else
                    echo "Reconnexion échouée. Branche USB ou --pair-usb."
                    exit 1
                fi
            else
                echo "Aucun device. Branche USB (--pair-usb pour bascule WiFi)."
                exit 1
            fi
            ;;
    esac

    # Mémorise pour prochaine fois si WiFi
    [[ "$TARGET_DEVICE" == *:* ]] && echo "$TARGET_DEVICE" > "$LAST_DEVICE_FILE"
}

# Chemin APK
find_apk() {
    local apk="$BUILD_DIR/android-build/$TARGET_NAME.apk"
    [[ -f "$apk" ]] && { echo "$apk"; return; }
    apk="$(find "$BUILD_DIR/android-build" -name "*.apk" 2>/dev/null | head -1)"
    [[ -z "$apk" ]] && return 1
    echo "$apk"
}

# Build + sign APK si absent ou --rebuild
ensure_apk() {
    local apk
    apk="$(find_apk || true)"
    if [[ -n "$apk" && $REBUILD -eq 0 ]]; then
        echo "APK existant : $apk (utilise --rebuild pour le régénérer)"
        return
    fi
    echo "=== Build APK (via deploy_android.sh apk) ==="
    bash "$SCRIPT_DIR/deploy_android.sh" apk
}

# Install avec fallback uninstall si signature différente
install_apk() {
    local apk
    apk="$(find_apk)" || { echo "APK introuvable"; exit 1; }
    echo "=== Install $apk sur $TARGET_DEVICE ==="
    if ! "$ADB" -s "$TARGET_DEVICE" install -r -t -g "$apk" 2>&1 | tee /tmp/meow-install.log; then
        if grep -q "INSTALL_FAILED_UPDATE_INCOMPATIBLE" /tmp/meow-install.log; then
            echo "Signature différente détectée → uninstall + retry"
            "$ADB" -s "$TARGET_DEVICE" uninstall "$PACKAGE_NAME" || true
            "$ADB" -s "$TARGET_DEVICE" install -r -t -g "$apk"
        else
            exit 1
        fi
    fi
}

# Launch l'activité
launch_app() {
    echo "=== Launch $PACKAGE_NAME ==="
    "$ADB" -s "$TARGET_DEVICE" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1
}

# Logcat filtré sur PID de l'app
tail_logcat() {
    local pid
    # Attend que l'app soit bien lancée
    for _ in 1 2 3 4 5; do
        pid="$("$ADB" -s "$TARGET_DEVICE" shell pidof "$PACKAGE_NAME" 2>/dev/null | tr -d '\r\n')"
        [[ -n "$pid" ]] && break
        sleep 1
    done
    if [[ -n "$pid" ]]; then
        echo "=== Logcat --pid=$pid (Ctrl-C pour quitter) ==="
        "$ADB" -s "$TARGET_DEVICE" logcat --pid="$pid" -v threadtime
    else
        echo "App pas en train de tourner — filtre par tag"
        "$ADB" -s "$TARGET_DEVICE" logcat -v threadtime \
            Meownopoly:V QtCore:V QtQml:V default:V AndroidRuntime:E '*:S'
    fi
}

# --- Main -------------------------------------------------------------------

# Flow spécial : pairage
[[ -n "$DO_PAIR" ]] && { cmd_pair "$DO_PAIR" "$PAIR_CODE"; exit 0; }
[[ $DO_PAIR_USB -eq 1 ]] && { cmd_pair_usb; exit 0; }

select_device

# Uninstall seulement
if [[ $DO_UNINSTALL -eq 1 ]]; then
    echo "=== Uninstall $PACKAGE_NAME ==="
    "$ADB" -s "$TARGET_DEVICE" uninstall "$PACKAGE_NAME"
    exit 0
fi

# Flow normal
if [[ $NO_INSTALL -eq 0 ]]; then
    ensure_apk
    install_apk
fi
launch_app

[[ $DO_LOGCAT -eq 1 ]] && tail_logcat

echo
echo "=== OK — deploy terminé sur $TARGET_DEVICE ==="
