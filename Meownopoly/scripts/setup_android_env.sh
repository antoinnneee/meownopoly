#!/usr/bin/env bash
# setup_android_env.sh
# Installe et configure l'environnement Android pour compiler Meownopoly
# avec Qt 6.10.3 Android (arm64-v8a) sur Linux aarch64 (Asahi/Fedora).
#
# Cible : Qt 6.10.3 -> NDK 27.2.12479018, SDK platform android-36,
#         build-tools 36.0.0, JDK 17.
#
# Usage : bash setup_android_env.sh [--dry-run]

set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

run() {
    echo ">>> $*"
    [[ $DRY_RUN -eq 0 ]] && eval "$*"
}

# --- Versions figées (doivent matcher le kit Qt 6.10.3) ----------------------
NDK_VERSION="27.2.12479018"
SDK_PLATFORM="android-36"
BUILD_TOOLS="36.0.0"
CMDLINE_TOOLS_VERSION="13114758"   # rev 17.0, Sep 2024
JDK_MAJOR="17"

# --- Chemins cibles ----------------------------------------------------------
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/$NDK_VERSION"
QT_HOST="$HOME/Qt/6.10.3/gcc_arm64"
QT_ANDROID="$HOME/Qt/6.10.3/android_arm64_v8a"

# --- Détection arch/distro ---------------------------------------------------
ARCH="$(uname -m)"
if [[ "$ARCH" != "aarch64" ]]; then
    echo "AVERTISSEMENT : arch=$ARCH (ce script cible aarch64 — Asahi M2)."
fi

if command -v dnf >/dev/null 2>&1; then
    PKG_MGR="dnf"
elif command -v pacman >/dev/null 2>&1; then
    PKG_MGR="pacman"
elif command -v apt >/dev/null 2>&1; then
    PKG_MGR="apt"
else
    echo "Pas de gestionnaire de paquets reconnu (dnf/pacman/apt). Installe JDK 17 manuellement."
    PKG_MGR="manual"
fi

# --- 1. JDK 17 ---------------------------------------------------------------
install_jdk() {
    if command -v java >/dev/null 2>&1 && java -version 2>&1 | grep -q "\"$JDK_MAJOR\."; then
        echo "JDK $JDK_MAJOR déjà installé."
        return
    fi
    case "$PKG_MGR" in
        dnf)    run "sudo dnf install -y java-${JDK_MAJOR}-openjdk-devel" ;;
        pacman) run "sudo pacman -S --needed jdk${JDK_MAJOR}-openjdk" ;;
        apt)    run "sudo apt update && sudo apt install -y openjdk-${JDK_MAJOR}-jdk" ;;
        *)      echo "Installe manuellement OpenJDK $JDK_MAJOR." ;;
    esac
}

# --- 2. adb / fastboot (facultatif, via distro) ------------------------------
install_host_tools() {
    if command -v adb >/dev/null 2>&1; then
        echo "adb déjà installé."
        return
    fi
    case "$PKG_MGR" in
        dnf)    run "sudo dnf install -y android-tools" ;;
        pacman) run "sudo pacman -S --needed android-tools" ;;
        apt)    run "sudo apt install -y android-tools-adb android-tools-fastboot" ;;
    esac
}

# --- 3. Android cmdline-tools ------------------------------------------------
install_cmdline_tools() {
    local dest="$ANDROID_SDK_ROOT/cmdline-tools/latest"
    if [[ -x "$dest/bin/sdkmanager" ]]; then
        echo "cmdline-tools déjà présents ($dest)."
        return
    fi
    local zip="/tmp/cmdline-tools.zip"
    local url="https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
    run "mkdir -p '$ANDROID_SDK_ROOT/cmdline-tools'"
    run "curl -L -o '$zip' '$url'"
    run "unzip -q -o '$zip' -d '$ANDROID_SDK_ROOT/cmdline-tools'"
    # L'archive extrait dans cmdline-tools/cmdline-tools/ — on renomme en latest/.
    run "rm -rf '$dest'"
    run "mv '$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools' '$dest'"
    run "rm -f '$zip'"
}

# --- 4. SDK packages via sdkmanager ------------------------------------------
install_sdk_packages() {
    local sdkmanager="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
    export ANDROID_SDK_ROOT
    # Accepte licences (stdin yes sur chaque prompt).
    run "yes | '$sdkmanager' --licenses >/dev/null || true"
    run "'$sdkmanager' --install \
        'platform-tools' \
        'platforms;$SDK_PLATFORM' \
        'build-tools;$BUILD_TOOLS' \
        'ndk;$NDK_VERSION'"
}

# --- 5. Vérif NDK aarch64 ----------------------------------------------------
# Depuis NDK r26b (2023), Google fournit des binaires Linux aarch64 natifs.
# sdkmanager tire le bon paquet selon l'arch du host. Si jamais x86_64 seul
# descend, le NDK tournera via box64 (lent mais fonctionnel sur Asahi).
verify_ndk() {
    local ndk_bin="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt"
    if [[ -d "$ndk_bin/linux-aarch64" ]]; then
        echo "NDK natif aarch64 OK."
    elif [[ -d "$ndk_bin/linux-x86_64" ]]; then
        echo "ATTENTION : NDK x86_64 installé. Sur Asahi, soit tu installes box64,"
        echo "soit tu forces une version NDK aarch64 (r27+ ships aarch64)."
    else
        echo "NDK introuvable sous $ndk_bin"
    fi
}

# --- 6. Export variables d'env ----------------------------------------------
write_envfile() {
    local envfile="$HOME/.meownopoly_android.env"
    cat > "$envfile" <<EOF
# Sourcer avant de builder Meownopoly Android :
#   source ~/.meownopoly_android.env

export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export ANDROID_HOME="\$ANDROID_SDK_ROOT"
export ANDROID_NDK_ROOT="$ANDROID_NDK_ROOT"
export ANDROID_NDK_HOME="\$ANDROID_NDK_ROOT"
export JAVA_HOME="\$(readlink -f /usr/bin/java | sed 's|/jre/bin/java||;s|/bin/java||')"

export QT_HOST_PATH="$QT_HOST"
export QT_ANDROID_PATH="$QT_ANDROID"

export PATH="\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$ANDROID_SDK_ROOT/platform-tools:\$PATH"
EOF
    echo "Fichier d'environnement : $envfile"
    echo "Ajoute à ton ~/.bashrc :  source ~/.meownopoly_android.env"
}

# --- Main --------------------------------------------------------------------
echo "=== Setup Android pour Meownopoly (Qt 6.10.3) ==="
echo "SDK     : $ANDROID_SDK_ROOT"
echo "NDK     : $ANDROID_NDK_ROOT"
echo "Qt host : $QT_HOST"
echo "Qt cible: $QT_ANDROID"
echo

install_jdk
install_host_tools
install_cmdline_tools
install_sdk_packages
verify_ndk
write_envfile

echo
echo "=== Terminé. ==="
echo "Vérifie avec :"
echo "  source ~/.meownopoly_android.env"
echo "  sdkmanager --list_installed"
echo "  ls \"\$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt\""
