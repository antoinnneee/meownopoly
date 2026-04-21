#!/bin/bash
# deploy_android.sh
# Construit l'APK (androiddeployqt + Gradle) et l'installe sur un device USB.
#
# Prérequis :
#   - Build .so déjà fait (bash configure_android.sh build)
#   - Device Android branché en USB avec "Débogage USB" activé
#   - adb dans le PATH (installé par setup_android_env.sh étape 2)
#
# Usage :
#   bash Meownopoly/scripts/deploy_android.sh              # build APK + install + launch
#   bash Meownopoly/scripts/deploy_android.sh apk          # build APK seulement
#   bash Meownopoly/scripts/deploy_android.sh install      # install APK déjà buildé
#   bash Meownopoly/scripts/deploy_android.sh launch       # launch app installée
#   bash Meownopoly/scripts/deploy_android.sh logcat       # suivre les logs device

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$(dirname "$PROJECT_DIR")/build-android"
PACKAGE_NAME="org.qtproject.example.Meownopoly"   # ajuster selon AndroidManifest
TARGET_NAME="Meownopoly"

# --- Sanity checks ----------------------------------------------------------
[[ -d "$BUILD_DIR" ]] || { echo "Build dir manquant : $BUILD_DIR — lance configure_android.sh build d'abord"; exit 1; }
command -v adb >/dev/null 2>&1 || { echo "adb introuvable — installe android-tools"; exit 1; }

cmd="${1:-all}"

# --- Étape 1 : build APK ----------------------------------------------------
build_apk() {
    echo "=== Build APK via androiddeployqt + Gradle ==="
    # La cible CMake 'apk' appelle androiddeployqt qui :
    #  - copie le .so dans l'Android project
    #  - appelle Gradle pour packager + signer (debug keystore par défaut)
    cmake --build "$BUILD_DIR" --target apk 2>&1 | tee /tmp/meow-apk.log
    echo
}

find_apk() {
    local apk
    apk="$(find "$BUILD_DIR" -name "*.apk" -path "*/outputs/apk/debug/*" 2>/dev/null | head -1)"
    if [[ -z "$apk" ]]; then
        apk="$(find "$BUILD_DIR" -name "*-debug.apk" 2>/dev/null | head -1)"
    fi
    if [[ -z "$apk" ]]; then
        echo "APK introuvable sous $BUILD_DIR — le build a-t-il réussi ?" >&2
        find "$BUILD_DIR" -name "*.apk" 2>/dev/null >&2
        exit 1
    fi
    echo "$apk"
}

# --- Étape 2 : install APK --------------------------------------------------
install_apk() {
    local apk
    apk="$(find_apk)"
    echo "=== APK : $apk ==="

    local devices
    devices="$(adb devices | awk 'NR>1 && /device$/ {print $1}')"
    if [[ -z "$devices" ]]; then
        echo "Aucun device Android détecté par adb."
        echo "Vérifie : USB branché, débogage USB activé, et lance 'adb devices' manuellement."
        exit 1
    fi
    echo "Devices :"
    echo "$devices"

    echo
    echo "=== Install APK ==="
    # -r = reinstall en gardant les données si possible
    # -t = autorise les APK testOnly (APK debug le sont souvent)
    # -g = grant toutes les permissions runtime auto (dev only)
    adb install -r -t -g "$apk"
    echo "Installé."
}

# --- Étape 3 : launch ------------------------------------------------------
launch_app() {
    echo "=== Launch $PACKAGE_NAME ==="
    # Essaye de déterminer le nom du package depuis l'APK si différent
    local apk
    apk="$(find_apk 2>/dev/null || true)"
    if [[ -n "$apk" ]] && command -v aapt >/dev/null 2>&1; then
        local extracted
        extracted="$(aapt dump badging "$apk" 2>/dev/null | awk -F"'" '/^package: name=/ {print $2}')"
        [[ -n "$extracted" ]] && PACKAGE_NAME="$extracted"
    fi
    adb shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 || {
        echo "Échec launch — vérifie le package name : $PACKAGE_NAME"
        echo "Liste des packages installés contenant 'meow' :"
        adb shell pm list packages | grep -i meow || true
    }
}

# --- Logcat suivi ----------------------------------------------------------
follow_logcat() {
    echo "=== Logcat filtré sur Meownopoly (Ctrl-C pour quitter) ==="
    adb logcat -v time | grep -iE "meownopoly|qt|libc|chromium|fatal"
}

# --- Main ------------------------------------------------------------------
case "$cmd" in
    apk)     build_apk ;;
    install) install_apk ;;
    launch)  launch_app ;;
    logcat)  follow_logcat ;;
    all|"")  build_apk && install_apk && launch_app ;;
    *)       echo "Usage : $0 [apk|install|launch|logcat|all]" ; exit 1 ;;
esac
