#!/bin/bash
# deploy_android_wifi.sh
# Déploiement WiFi vers un device Android — pas de câble USB nécessaire
# après le pairage initial.
#
# Deux modes :
#   1. Wireless Debugging (Android 11+) — pairage via code à 6 chiffres
#      Paramètres → Options développeur → Débogage sans fil
#   2. TCP/IP legacy (Android 5+) — besoin d'un USB une fois pour activer
#
# Usage :
#   bash deploy_android_wifi.sh pair <IP:PORT> <CODE>   # 1er pairage Android 11+
#   bash deploy_android_wifi.sh pair-usb                # active TCP/IP via USB
#   bash deploy_android_wifi.sh connect <IP>            # reconnexion
#   bash deploy_android_wifi.sh deploy <IP>             # connect + install + launch
#   bash deploy_android_wifi.sh disconnect              # déconnexion
#   bash deploy_android_wifi.sh status                  # état des devices

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$(dirname "$PROJECT_DIR")/build-android"
TARGET_NAME="Meownopoly"
PACKAGE_NAME="org.qtproject.example.Meownopoly"
WIFI_PORT="${ADB_WIFI_PORT:-5555}"

# Force le adb natif aarch64 (Fedora) — le SDK adb x86_64 crashe sous box64.
if [[ -x /usr/bin/adb ]]; then
    ADB=/usr/bin/adb
else
    ADB="$(command -v adb)" || { echo "adb introuvable — 'sudo dnf install android-tools'"; exit 1; }
fi

# ---------------------------------------------------------------------------
find_apk() {
    local apk="$BUILD_DIR/android-build/$TARGET_NAME.apk"
    [[ -f "$apk" ]] && { echo "$apk"; return; }
    apk="$(find "$BUILD_DIR/android-build" -name "*.apk" 2>/dev/null | head -1)"
    [[ -z "$apk" ]] && { echo "APK introuvable — build d'abord avec deploy_android.sh apk" >&2; exit 1; }
    echo "$apk"
}

# Normalise une adresse : accepte 'IP', 'IP:PORT', ajoute port WiFi par défaut.
normalize_addr() {
    local addr="$1"
    [[ "$addr" == *:* ]] || addr="$addr:$WIFI_PORT"
    echo "$addr"
}

# Mode 1 : pairage Android 11+ Wireless Debugging
# Sur le téléphone : Options développeur → Débogage sans fil → "Associer
# l'appareil avec un code d'association" → affiche IP:PORT + code 6 chiffres
cmd_pair() {
    local addr="${1:?Usage: pair <IP:PORT> <CODE>}"
    local code="${2:?Code 6 chiffres manquant}"
    echo "=== Pairage Android 11+ Wireless Debugging ==="
    echo "Cible : $addr"
    "$ADB" pair "$addr" "$code"
    echo
    echo "Pairage OK. Sur le téléphone, note l'adresse IP:PORT (généralement"
    echo "différente du port de pairage) affichée sous 'Adresse IP et port'"
    echo "puis lance : $0 connect <IP>[:PORT]"
}

# Mode 2 : TCP/IP legacy via USB (Android < 11 ou plus simple)
# Le téléphone doit être branché USB, débogage USB activé.
cmd_pair_usb() {
    echo "=== Activation TCP/IP via USB ==="
    echo "Vérifie que le téléphone est branché USB + débogage USB activé."
    local devices
    devices="$("$ADB" devices | awk 'NR>1 && /device$/ {print $1}')"
    [[ -z "$devices" ]] && { echo "Aucun device USB détecté"; exit 1; }
    echo "Device USB : $devices"
    # IP du téléphone sur le wifi
    local ip
    ip="$("$ADB" -s "$devices" shell ip route | awk '/wlan0/ {for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}' | head -1)"
    if [[ -z "$ip" ]]; then
        ip="$("$ADB" -s "$devices" shell ip -f inet addr show wlan0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -1)"
    fi
    [[ -z "$ip" ]] && { echo "Pas d'IP WiFi détectée. Connecte le téléphone au WiFi d'abord."; exit 1; }
    echo "IP WiFi du téléphone : $ip"
    "$ADB" -s "$devices" tcpip "$WIFI_PORT"
    sleep 2
    "$ADB" connect "$ip:$WIFI_PORT"
    echo
    echo "TCP/IP activé. Tu peux débrancher le câble USB."
    echo "Pour re-déployer : $0 deploy $ip"
}

cmd_connect() {
    local addr
    addr="$(normalize_addr "${1:?Usage: connect <IP>[:PORT]}")"
    echo "=== Connexion $addr ==="
    "$ADB" connect "$addr"
    "$ADB" devices
}

cmd_disconnect() {
    echo "=== Déconnexion ==="
    "$ADB" disconnect
}

cmd_status() {
    "$ADB" devices -l
}

cmd_apk() {
    # Délègue la construction signée à deploy_android.sh (keystore + rebuild)
    bash "$(dirname "${BASH_SOURCE[0]}")/deploy_android.sh" apk
}

cmd_deploy() {
    local addr
    addr="$(normalize_addr "${1:?Usage: deploy <IP>[:PORT] [--rebuild]}")"
    local rebuild=0
    shift || true
    [[ "${1:-}" == "--rebuild" ]] && rebuild=1

    [[ $rebuild -eq 1 ]] && cmd_apk

    cmd_connect "$addr" >/dev/null
    # Vérifie que le device est bien connecté
    if ! "$ADB" devices | grep -q "${addr}.*device\$"; then
        echo "Connexion échouée vers $addr" >&2
        "$ADB" devices
        exit 1
    fi

    local apk
    apk="$(find_apk)"
    echo "=== Install APK ($apk) sur $addr ==="
    if ! "$ADB" -s "$addr" install -r -t -g "$apk"; then
        echo
        echo "Install failed. Si INSTALL_PARSE_FAILED_NO_CERTIFICATES :"
        echo "  bash $0 deploy $addr --rebuild    # re-build APK signé"
        echo "Si INSTALL_FAILED_UPDATE_INCOMPATIBLE (autre signature installée) :"
        echo "  $ADB -s $addr uninstall $PACKAGE_NAME"
        exit 1
    fi

    echo "=== Launch $PACKAGE_NAME ==="
    "$ADB" -s "$addr" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1
}

cmd_logcat() {
    local addr
    addr="$(normalize_addr "${1:?Usage: logcat <IP>[:PORT]}")"
    "$ADB" -s "$addr" logcat -v time | grep -iE "meownopoly|qt|fatal|chromium"
}

# ---------------------------------------------------------------------------
cmd="${1:-help}"
shift || true
case "$cmd" in
    pair)       cmd_pair "$@" ;;
    pair-usb)   cmd_pair_usb ;;
    connect)    cmd_connect "$@" ;;
    disconnect) cmd_disconnect ;;
    apk)        cmd_apk ;;
    deploy)     cmd_deploy "$@" ;;
    status)     cmd_status ;;
    logcat)     cmd_logcat "$@" ;;
    help|*)     sed -n '2,/^#$/p' "$0" | sed 's|^# \?||' ;;
esac
