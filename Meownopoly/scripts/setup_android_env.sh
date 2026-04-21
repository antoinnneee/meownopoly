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
# Ordre : paquet distro -> repo Adoptium (dnf) -> tarball Adoptium dans ~/opt.
JDK_TARBALL_URL="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.13%2B11/OpenJDK17U-jdk_aarch64_linux_hotspot_17.0.13_11.tar.gz"
JDK_TARBALL_DIR="$HOME/opt/jdk-17.0.13+11"
CUSTOM_JAVA_HOME=""

_java17_present() {
    command -v java >/dev/null 2>&1 && java -version 2>&1 | grep -q "\"$JDK_MAJOR\."
}

install_jdk_distro() {
    case "$PKG_MGR" in
        dnf)    sudo dnf install -y "java-${JDK_MAJOR}-openjdk-devel" 2>/dev/null ;;
        pacman) sudo pacman -S --needed --noconfirm "jdk${JDK_MAJOR}-openjdk" 2>/dev/null ;;
        apt)    sudo apt update -qq && sudo apt install -y "openjdk-${JDK_MAJOR}-jdk" 2>/dev/null ;;
        *)      return 1 ;;
    esac
}

install_jdk_adoptium_repo() {
    [[ "$PKG_MGR" != "dnf" ]] && return 1
    echo ">>> Ajout du repo Adoptium"
    if [[ $DRY_RUN -eq 0 ]]; then
        sudo tee /etc/yum.repos.d/adoptium.repo >/dev/null <<'EOF'
[Adoptium]
name=Adoptium
baseurl=https://packages.adoptium.net/artifactory/rpm/fedora/$releasever/$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.adoptium.net/artifactory/api/gpg/key/public
EOF
        sudo dnf install -y temurin-17-jdk
    fi
}

install_jdk_tarball() {
    echo ">>> Téléchargement Adoptium Temurin 17 (tarball aarch64)"
    if [[ $DRY_RUN -eq 0 ]]; then
        mkdir -p "$HOME/opt"
        local tmp="/tmp/jdk17-aarch64.tar.gz"
        curl -L -o "$tmp" "$JDK_TARBALL_URL"
        tar xzf "$tmp" -C "$HOME/opt"
        rm -f "$tmp"
    fi
    CUSTOM_JAVA_HOME="$JDK_TARBALL_DIR"
}

install_jdk() {
    if _java17_present; then
        echo "JDK $JDK_MAJOR déjà installé."
        return
    fi
    echo ">>> Tentative JDK via paquet distro"
    if install_jdk_distro && _java17_present; then
        return
    fi
    echo ">>> Distro KO. Tentative repo Adoptium"
    if install_jdk_adoptium_repo && [[ -x /usr/lib/jvm/temurin-17-jdk/bin/java ]]; then
        CUSTOM_JAVA_HOME="/usr/lib/jvm/temurin-17-jdk"
        return
    fi
    echo ">>> Repo Adoptium KO. Fallback tarball dans ~/opt"
    install_jdk_tarball
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
EOF
    if [[ -n "$CUSTOM_JAVA_HOME" ]]; then
        echo "export JAVA_HOME=\"$CUSTOM_JAVA_HOME\"" >> "$envfile"
        echo "export PATH=\"\$JAVA_HOME/bin:\$PATH\"" >> "$envfile"
    else
        echo "export JAVA_HOME=\"\$(readlink -f \$(command -v java) | sed 's|/jre/bin/java||;s|/bin/java||')\"" >> "$envfile"
    fi
    cat >> "$envfile" <<EOF

export QT_HOST_PATH="$QT_HOST"
export QT_ANDROID_PATH="$QT_ANDROID"

# platform-tools du SDK Google sont x86_64 → crashent via box64 (adb SIGSEGV).
# On met le PATH système EN PREMIER pour que /usr/bin/adb (natif aarch64, paquet
# android-tools de Fedora) soit prioritaire. Le SDK platform-tools reste
# accessible en fallback pour fastboot/sqlite3/etc.
export PATH="/usr/bin:/usr/sbin:\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$ANDROID_SDK_ROOT/platform-tools:\$PATH"

# Box64 : émulation x86_64 in-process pour faire tourner le clang NDK.
# Le NDK r27 ne fournit pas de toolchain aarch64 natif sous dl.google.com ;
# sdkmanager installe donc le clang x86_64 qu'on doit émuler.
# Ces libs sont extraites depuis Debian amd64 pool par setup_android_env.sh.
export BOX64_LD_LIBRARY_PATH="\$HOME/x86_64-libs/usr/lib/x86_64-linux-gnu"
EOF
    echo "Fichier d'environnement : $envfile"
    echo "Ajoute à ton ~/.bashrc :  source ~/.meownopoly_android.env"
}

# --- 7. Box64 + libs x86_64 pour émuler le clang NDK -------------------------
# Sur Asahi, binfmt_misc route x86_64 via FEX+muvm par défaut, qui n'est pas
# utilisable pour un build (VM laggée, pas de visibilité des fichiers
# récemment créés, plantage en parallèle). Box64 (émulation in-process,
# même FS que le host) est la solution. Nécessite des libs x86_64 (libgcc_s,
# libstdc++, etc.) que Fedora aarch64 ne livre pas → on les extrait depuis
# le pool Debian amd64.
install_box64() {
    if ! command -v box64 >/dev/null 2>&1; then
        case "$PKG_MGR" in
            dnf) run "sudo dnf install -y box64-asahi box64-binfmts" ;;
            *)   echo "Installe box64 manuellement pour ta distro." ; return 1 ;;
        esac
    else
        echo "box64 déjà installé."
    fi

    # Désactive les dispatchers FEX qui ont priorité sur box64
    if [[ -f /proc/sys/fs/binfmt_misc/binfmt-dispatcher-x86_64 ]]; then
        run "sudo sh -c 'echo 0 > /proc/sys/fs/binfmt_misc/binfmt-dispatcher-x86_64'"
    fi
    if [[ -f /proc/sys/fs/binfmt_misc/FEX-x86_64 ]]; then
        run "sudo sh -c 'echo 0 > /proc/sys/fs/binfmt_misc/FEX-x86_64'"
    fi
}

install_x86_64_libs() {
    local dest="$HOME/x86_64-libs"
    local target="$dest/usr/lib/x86_64-linux-gnu"
    # Ajouts : libc6 (contient libc.so.6, libdl, libpthread, libm, librt, libresolv)
    # nécessaire parce que le wrapper libc.so.6 de box64 ne connaît pas certains
    # symboles comme nftw utilisé par aapt2. Avec la lib x86_64 complète dans
    # BOX64_LD_LIBRARY_PATH, box64 charge la version emulée qui a le symbole.
    local force_refresh="${1:-0}"

    if [[ "$force_refresh" != "force" && -f "$target/libgcc_s.so.1" && -f "$target/libstdc++.so.6" && -f "$target/libc.so.6" ]]; then
        echo "libs x86_64 déjà présentes (incl. libc.so.6) : $target"
        return
    fi

    echo ">>> Téléchargement libs x86_64 depuis Debian pool"
    [[ $DRY_RUN -eq 1 ]] && return

    mkdir -p "$dest"
    cd "$dest"

    local debs=(
        "http://ftp.debian.org/debian/pool/main/g/gcc-14/libgcc-s1_14.2.0-19_amd64.deb"
        "http://ftp.debian.org/debian/pool/main/g/gcc-14/libstdc++6_14.2.0-19_amd64.deb"
        # libc6 — fournit libc.so.6, libdl, libpthread, libm, librt, libresolv
        "http://ftp.debian.org/debian/pool/main/g/glibc/libc6_2.40-6_amd64.deb"
    )

    for url in "${debs[@]}"; do
        local deb="$(basename "$url")"
        echo "  -> $deb"
        curl -sL -o "$deb" "$url"
        ar x "$deb"
        # glibc deb utilise data.tar.zst, gcc utilise data.tar.xz
        if [[ -f data.tar.zst ]]; then
            tar xf data.tar.zst
        else
            tar xf data.tar.xz
        fi
        rm -f control.tar.* data.tar.* debian-binary "$deb"
    done

    # Symlinks vers les noms attendus si glibc pose les libs avec versions spécifiques
    (cd "$target" && for f in libc.so.6 libm.so.6 libdl.so.2 libpthread.so.0 librt.so.1 libresolv.so.2; do
        [[ -e "$f" ]] || ln -sf "$(ls "$f"* 2>/dev/null | head -1)" "$f" 2>/dev/null || true
    done)

    echo "Libs x86_64 installées dans $target :"
    ls "$target" | grep -E "\.so" | head -20
    cd - >/dev/null
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
install_box64
install_x86_64_libs
write_envfile

# Debug keystore pour que le premier build APK ne sorte pas non-signé
echo
if [[ $DRY_RUN -eq 0 ]]; then
    bash "$(dirname "${BASH_SOURCE[0]}")/ensure_keystore.sh" || true
fi

echo
echo "=== Terminé. ==="
echo "Vérifie avec :"
echo "  source ~/.meownopoly_android.env"
echo "  sdkmanager --list_installed"
echo "  ls \"\$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt\""
