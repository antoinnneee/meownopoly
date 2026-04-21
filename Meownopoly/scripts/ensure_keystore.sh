#!/bin/bash
# ensure_keystore.sh
# Génère le debug keystore Android si absent (~/.android/debug.keystore).
# Sans lui, androiddeployqt produit un APK non-signé et adb install rejette
# avec INSTALL_PARSE_FAILED_NO_CERTIFICATES.
#
# Idempotent : skip si le keystore existe déjà.

set -euo pipefail

KEYSTORE="$HOME/.android/debug.keystore"
ALIAS="androiddebugkey"
STOREPASS="android"   # convention Android SDK — mot de passe public, dev only
KEYPASS="android"

# --- Trouver keytool --------------------------------------------------------
if [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/keytool" ]]; then
    KEYTOOL="$JAVA_HOME/bin/keytool"
elif command -v keytool >/dev/null 2>&1; then
    KEYTOOL="$(command -v keytool)"
else
    echo "keytool introuvable — JDK 17 installé ? 'source ~/.meownopoly_android.env' d'abord ?"
    exit 1
fi

# --- Skip si déjà présent ---------------------------------------------------
if [[ -f "$KEYSTORE" ]]; then
    echo "Debug keystore déjà présent : $KEYSTORE"
    "$KEYTOOL" -list -v -keystore "$KEYSTORE" -storepass "$STOREPASS" 2>/dev/null \
        | grep -E "^Alias name:|^Creation date:|^Valid from:" | head -3
    exit 0
fi

# --- Génération -------------------------------------------------------------
mkdir -p "$(dirname "$KEYSTORE")"
echo "=== Génération debug keystore : $KEYSTORE ==="
"$KEYTOOL" -genkey -v \
    -keystore "$KEYSTORE" \
    -storepass "$STOREPASS" \
    -keypass "$KEYPASS" \
    -alias "$ALIAS" \
    -keyalg RSA -keysize 2048 \
    -validity 10000 \
    -dname "CN=Meownopoly, O=Meownopoly, C=FR"

echo
echo "Keystore généré. androiddeployqt va maintenant pouvoir signer les APK debug."
