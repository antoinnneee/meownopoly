#!/bin/bash
# setup_android_openssl.sh
# Clone le repo KDAB android_openssl qui fournit libcrypto.so/libssl.so
# précompilés pour Android (toutes ABIs) + un CMakeLists d'intégration.
# Sans ces libs embarquées dans l'APK, Qt Network échoue avec "TLS
# initialization failed" sur tout HTTPS / WebSocket.
#
# Idempotent : skip si déjà présent.

set -euo pipefail

DEST="$HOME/android_openssl"
REPO="https://github.com/KDAB/android_openssl.git"

if [[ -d "$DEST/.git" ]]; then
    echo "android_openssl déjà cloné : $DEST"
    git -C "$DEST" pull --ff-only 2>/dev/null || true
else
    echo "=== Clone $REPO → $DEST ==="
    git clone --depth 1 "$REPO" "$DEST"
fi

# Vérification
if [[ -f "$DEST/CMakeLists.txt" ]]; then
    echo "OK : $DEST/CMakeLists.txt présent"
    ls "$DEST"/ssl_3/arm64-v8a/*.so 2>/dev/null | head -5
else
    echo "ERREUR : CMakeLists.txt manquant dans $DEST" >&2
    exit 1
fi

echo
echo "Reconfigure + rebuild l'APK pour embarquer les libs :"
echo "  bash Meownopoly/scripts/configure_android.sh clean build"
echo "  bash Meownopoly/scripts/deploy_android_wifi.sh deploy <IP> --rebuild"
