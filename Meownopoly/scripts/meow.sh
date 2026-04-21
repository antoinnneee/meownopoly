#!/bin/bash
# meow.sh — Script unique de déploiement Meownopoly vers Android
#
# Toutes les bibliothèques (box64, qemu, libs x86_64, JDK Temurin 17,
# debug keystore, android_openssl) sont supposées déjà installées par
# le setup initial. Ce script gère juste le cycle quotidien.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$(dirname "$PROJECT_DIR")/build-android"
TARGET_NAME="Meownopoly"
PACKAGE_NAME="org.qtproject.example.Meownopoly"
LAST_DEVICE_FILE="$HOME/.meownopoly_last_device"
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

show_help() {
    cat <<EOF
═══════════════════════════════════════════════════════════════════════
  meow.sh — Déploiement Meownopoly Android
═══════════════════════════════════════════════════════════════════════
  Usage : ./meow.sh [COMMANDE] [--wifi IP] [--usb]

  COMMANDES :
    (aucune)    Build si APK absent + install + launch     [par défaut]
    run         Même chose que (aucune)
    reinstall   Force rebuild APK + install + launch
    delete      Désinstalle l'app du device
    reconfigure Full CMake reconfigure (wipe build dir)
    logs        Alias de ./logcat_android.sh (tail live)
    help        Affiche cette aide

  OPTIONS TRANSPORT :
    --wifi [IP] Force WiFi (IP optionnelle, dernière mémorisée sinon)
    --usb       Force USB
    (auto)      Détection auto : USB > WiFi connecté > dernière IP

  EXEMPLES :
    ./meow.sh                       # Lance sur premier device
    ./meow.sh reinstall              # Recompile APK + relance
    ./meow.sh delete                 # Uninstall
    ./meow.sh --wifi 192.168.1.15    # Force WiFi
    ./meow.sh logs                   # Voir logs app en temps réel
═══════════════════════════════════════════════════════════════════════

EOF
}

# Affiche l'aide au début de chaque run
show_help

# --- Env -------------------------------------------------------------------
[[ -f "$HOME/.meownopoly_android.env" ]] && source "$HOME/.meownopoly_android.env"

# Adb natif aarch64 (Fedora android-tools), pas le SDK x86_64
if [[ -x /usr/bin/adb ]]; then
    ADB=/usr/bin/adb
else
    ADB="$(command -v adb)" || { echo "ERR : adb introuvable"; exit 1; }
fi

# --- Parse args ------------------------------------------------------------
COMMAND=run
MODE=auto
WIFI_IP=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        run|reinstall|delete|uninstall|reconfigure|logs|help) COMMAND="$1"; shift ;;
        --wifi) MODE=wifi; shift; [[ $# -gt 0 && "$1" != --* && "$1" != -* ]] && { WIFI_IP="$1"; shift; } ;;
        --usb)  MODE=usb; shift ;;
        -h|--help) COMMAND=help; shift ;;
        *) echo "Commande inconnue : $1"; exit 1 ;;
    esac
done

[[ "$COMMAND" == "uninstall" ]] && COMMAND=delete
[[ "$COMMAND" == "help" ]] && exit 0

# --- Helpers ---------------------------------------------------------------

find_apk() {
    local apk="$BUILD_DIR/android-build/$TARGET_NAME.apk"
    [[ -f "$apk" ]] && { echo "$apk"; return; }
    apk="$(find "$BUILD_DIR/android-build" -name "*.apk" 2>/dev/null | head -1)"
    [[ -z "$apk" ]] && return 1
    echo "$apk"
}

ensure_keystore() {
    local ks="$HOME/.android/debug.keystore"
    [[ -f "$ks" ]] && return
    local keytool
    keytool="${JAVA_HOME:-/usr/lib/jvm/temurin-17-jdk}/bin/keytool"
    [[ -x "$keytool" ]] || keytool="$(command -v keytool)"
    mkdir -p "$(dirname "$ks")"
    echo ">>> Génération debug keystore"
    "$keytool" -genkey -v -keystore "$ks" -storepass android -keypass android \
        -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=Meownopoly, O=Meownopoly, C=FR"
}

sign_apk() {
    local apk="$BUILD_DIR/android-build/$TARGET_NAME.apk"
    local unsigned
    unsigned="$(find "$BUILD_DIR/android-build/build/outputs/apk" -name "*-unsigned.apk" 2>/dev/null | head -1)"
    [[ -z "$unsigned" ]] && unsigned="$(find "$BUILD_DIR/android-build/build/outputs/apk" -name "*.apk" 2>/dev/null | head -1)"
    [[ -z "$unsigned" || ! -f "$unsigned" ]] && { echo "Pas d'APK Gradle à signer"; return 1; }

    local buildtools
    buildtools="$(find "${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}/build-tools" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | tail -1)"
    local apksigner="$buildtools/apksigner"
    local zipalign="$buildtools/zipalign"

    local aligned="/tmp/${TARGET_NAME}-aligned.apk"
    echo ">>> zipalign + apksigner (debug keystore)"
    "$zipalign" -f -p 4 "$unsigned" "$aligned"
    "$apksigner" sign \
        --ks "$HOME/.android/debug.keystore" \
        --ks-pass pass:android --key-pass pass:android \
        --out "$apk" "$aligned"
    rm -f "$aligned"
    echo "APK signé : $apk"
}

build_apk() {
    echo "=== Build APK (androiddeployqt + Gradle) ==="
    ensure_keystore
    rm -f "$BUILD_DIR/android-build/$TARGET_NAME.apk"
    cmake --build "$BUILD_DIR" --target "${TARGET_NAME}_make_apk" 2>&1 | tee /tmp/meow-apk.log
    sign_apk
}

select_device() {
    local devices wifi_devs usb_devs
    devices="$("$ADB" devices | awk 'NR>1 && /device$/ {print $1}')"
    wifi_devs="$(echo "$devices" | grep ':' || true)"
    usb_devs="$(echo "$devices" | grep -v ':' | grep -v '^$' || true)"

    case "$MODE" in
        wifi)
            if [[ -n "$WIFI_IP" ]]; then
                [[ "$WIFI_IP" == *:* ]] || WIFI_IP="$WIFI_IP:5555"
                "$ADB" connect "$WIFI_IP" >/dev/null
                TARGET_DEVICE="$WIFI_IP"
            elif [[ -f "$LAST_DEVICE_FILE" ]]; then
                local last; last="$(cat "$LAST_DEVICE_FILE")"
                echo "Reconnexion à $last..."
                "$ADB" connect "$last" >/dev/null
                TARGET_DEVICE="$last"
            elif [[ -n "$wifi_devs" ]]; then
                TARGET_DEVICE="$(echo "$wifi_devs" | head -1)"
            else
                echo "ERR : aucun device WiFi dispo, pas d'IP mémorisée"; exit 1
            fi ;;
        usb)
            [[ -z "$usb_devs" ]] && { echo "ERR : aucun device USB"; exit 1; }
            TARGET_DEVICE="$(echo "$usb_devs" | head -1)" ;;
        auto)
            if [[ -n "$usb_devs" ]]; then
                TARGET_DEVICE="$(echo "$usb_devs" | head -1)"
                echo "Device USB : $TARGET_DEVICE"
            elif [[ -n "$wifi_devs" ]]; then
                TARGET_DEVICE="$(echo "$wifi_devs" | head -1)"
                echo "Device WiFi déjà connecté : $TARGET_DEVICE"
            elif [[ -f "$LAST_DEVICE_FILE" ]]; then
                local last; last="$(cat "$LAST_DEVICE_FILE")"
                echo "Tentative reconnexion WiFi $last..."
                "$ADB" connect "$last" >/dev/null 2>&1 || true
                if "$ADB" devices | grep -q "${last}.*device\$"; then
                    TARGET_DEVICE="$last"
                else
                    echo "ERR : pas de device, branche USB ou active Wireless Debugging"; exit 1
                fi
            else
                echo "ERR : aucun device détecté"; exit 1
            fi ;;
    esac
    [[ "$TARGET_DEVICE" == *:* ]] && echo "$TARGET_DEVICE" > "$LAST_DEVICE_FILE"
}

install_apk() {
    local apk; apk="$(find_apk)" || { echo "ERR : APK introuvable — reinstall ?"; exit 1; }
    echo "=== Install $apk sur $TARGET_DEVICE ==="
    if ! "$ADB" -s "$TARGET_DEVICE" install -r -t -g "$apk" 2>&1 | tee /tmp/meow-install.log; then
        if grep -q "INSTALL_FAILED_UPDATE_INCOMPATIBLE" /tmp/meow-install.log; then
            echo "Signature différente → uninstall + retry"
            "$ADB" -s "$TARGET_DEVICE" uninstall "$PACKAGE_NAME" || true
            "$ADB" -s "$TARGET_DEVICE" install -r -t -g "$apk"
        else
            exit 1
        fi
    fi
}

launch_app() {
    echo "=== Launch $PACKAGE_NAME ==="
    "$ADB" -s "$TARGET_DEVICE" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 >/dev/null
    echo "App démarrée. Pour voir les logs : ./logcat_android.sh"
}

cmd_delete() {
    select_device
    echo "=== Uninstall $PACKAGE_NAME ==="
    "$ADB" -s "$TARGET_DEVICE" uninstall "$PACKAGE_NAME"
}

cmd_reconfigure() {
    echo "=== Full clean reconfigure ==="
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    local qt_cmake="${QT_ANDROID_PATH:-$HOME/Qt/6.10.3/android_arm64_v8a}/bin/qt-cmake"
    local ndk="${ANDROID_NDK_ROOT:-$HOME/Android/Sdk/ndk/27.2.12479018}"
    local sysroot="$ndk/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
    local sdk="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
    local qt_host="${QT_HOST_PATH:-$HOME/Qt/6.10.3/gcc_arm64}"
    local gfx_include="$HOME/android-gfx-include"

    # Cache initial pour skip détection qui plante via emulation
    cat > "$BUILD_DIR/init_cache.cmake" <<CMAKE_INIT
set(CMAKE_C_COMPILER_WORKS TRUE CACHE BOOL "" FORCE)
set(CMAKE_CXX_COMPILER_WORKS TRUE CACHE BOOL "" FORCE)
set(CMAKE_C_COMPILER_FORCED TRUE CACHE BOOL "" FORCE)
set(CMAKE_CXX_COMPILER_FORCED TRUE CACHE BOOL "" FORCE)
set(CMAKE_C_COMPILER_ID "Clang" CACHE STRING "" FORCE)
set(CMAKE_CXX_COMPILER_ID "Clang" CACHE STRING "" FORCE)
set(CMAKE_C_COMPILER_VERSION "18.0.3" CACHE STRING "" FORCE)
set(CMAKE_CXX_COMPILER_VERSION "18.0.3" CACHE STRING "" FORCE)
set(CMAKE_C_COMPILER_ID_RUN TRUE CACHE BOOL "" FORCE)
set(CMAKE_CXX_COMPILER_ID_RUN TRUE CACHE BOOL "" FORCE)
set(CMAKE_C_COMPILER_ABI "ELF" CACHE STRING "" FORCE)
set(CMAKE_CXX_COMPILER_ABI "ELF" CACHE STRING "" FORCE)
set(CMAKE_C_SIZEOF_DATA_PTR 8 CACHE STRING "" FORCE)
set(CMAKE_CXX_SIZEOF_DATA_PTR 8 CACHE STRING "" FORCE)
set(CMAKE_C_STANDARD_COMPUTED_DEFAULT "17" CACHE STRING "" FORCE)
set(CMAKE_CXX_STANDARD_COMPUTED_DEFAULT "17" CACHE STRING "" FORCE)
set(CMAKE_C_EXTENSIONS_COMPUTED_DEFAULT "ON" CACHE STRING "" FORCE)
set(CMAKE_CXX_EXTENSIONS_COMPUTED_DEFAULT "ON" CACHE STRING "" FORCE)
set(CMAKE_C_COMPILE_FEATURES "c_std_90;c_std_99;c_std_11;c_std_17;c_std_23" CACHE STRING "" FORCE)
set(CMAKE_CXX_COMPILE_FEATURES "cxx_std_98;cxx_std_11;cxx_std_14;cxx_std_17;cxx_std_20;cxx_std_23;cxx_std_26;cxx_decltype;cxx_constexpr;cxx_rvalue_references;cxx_nullptr;cxx_override;cxx_range_for;cxx_static_assert;cxx_lambdas;cxx_noexcept;cxx_auto_type;cxx_variadic_templates" CACHE STRING "" FORCE)
set(CMAKE_CXX11_COMPILE_FEATURES "cxx_std_11" CACHE STRING "" FORCE)
set(CMAKE_CXX14_COMPILE_FEATURES "cxx_std_14" CACHE STRING "" FORCE)
set(CMAKE_CXX17_COMPILE_FEATURES "cxx_std_17" CACHE STRING "" FORCE)
set(CMAKE_CXX20_COMPILE_FEATURES "cxx_std_20" CACHE STRING "" FORCE)
set(CMAKE_CXX23_COMPILE_FEATURES "cxx_std_23" CACHE STRING "" FORCE)
set(CMAKE_HAVE_LIBC_PTHREAD TRUE CACHE BOOL "" FORCE)
set(CMAKE_USE_PTHREADS_INIT TRUE CACHE BOOL "" FORCE)
set(THREADS_FOUND TRUE CACHE BOOL "" FORCE)
set(Threads_FOUND TRUE CACHE BOOL "" FORCE)
set(CMAKE_THREAD_LIBS_INIT "" CACHE STRING "" FORCE)
set(HAVE_STDATOMIC TRUE CACHE BOOL "" FORCE)
set(HAVE_STDATOMIC_WITH_LIB TRUE CACHE BOOL "" FORCE)
set(HAVE_EGL TRUE CACHE BOOL "" FORCE)
set(HAVE_GLESv2 TRUE CACHE BOOL "" FORCE)
set(HAVE_GLESv3 TRUE CACHE BOOL "" FORCE)
set(HAVE_OPENGL_ES_2 TRUE CACHE BOOL "" FORCE)
set(HAVE_OPENGL_ES_3 TRUE CACHE BOOL "" FORCE)
set(EGL_INCLUDE_DIR "$gfx_include" CACHE PATH "" FORCE)
set(GLESv2_INCLUDE_DIR "$gfx_include" CACHE PATH "" FORCE)
set(Vulkan_INCLUDE_DIR "$gfx_include" CACHE PATH "" FORCE)
set(VulkanHeaders_INCLUDE_DIR "$gfx_include" CACHE PATH "" FORCE)
set(WrapVulkanHeaders_INCLUDE_DIR "$gfx_include" CACHE PATH "" FORCE)
set(EGL_LIBRARY "$sysroot/usr/lib/aarch64-linux-android/28/libEGL.so" CACHE FILEPATH "" FORCE)
set(GLESv2_LIBRARY "$sysroot/usr/lib/aarch64-linux-android/28/libGLESv2.so" CACHE FILEPATH "" FORCE)
CMAKE_INIT

    "$qt_cmake" \
        -S "$PROJECT_DIR" -B "$BUILD_DIR" -G Ninja \
        -C "$BUILD_DIR/init_cache.cmake" \
        -DCMAKE_BUILD_TYPE=Release \
        -DQT_HOST_PATH="$qt_host" \
        -DQT_ANDROID_ABIS="arm64-v8a" \
        -DQT_ANDROID_BUILD_ALL_ABIS=OFF \
        -DANDROID_NDK="$ndk" -DANDROID_NDK_ROOT="$ndk" -DCMAKE_ANDROID_NDK="$ndk" \
        -DANDROID_SDK_ROOT="$sdk" -DANDROID_SDK="$sdk" \
        -DANDROID_PLATFORM=android-28 \
        -DCMAKE_C_COMPILER_TARGET="aarch64-linux-android28" \
        -DCMAKE_CXX_COMPILER_TARGET="aarch64-linux-android28" \
        -DCMAKE_SYSROOT="$sysroot" \
        -DCMAKE_C_FLAGS="--target=aarch64-linux-android28 --sysroot=$sysroot" \
        -DCMAKE_CXX_FLAGS="--target=aarch64-linux-android28 --sysroot=$sysroot -cxx-isystem $sysroot/usr/include/c++/v1"
    echo "=== Reconfigure OK ==="
}

# --- Main ------------------------------------------------------------------
case "$COMMAND" in
    logs)
        exec "$SCRIPT_DIR/logcat_android.sh" ;;
    delete)
        cmd_delete ;;
    reconfigure)
        cmd_reconfigure ;;
    reinstall)
        select_device
        build_apk
        install_apk
        launch_app ;;
    run)
        select_device
        if ! find_apk >/dev/null 2>&1; then
            echo "Pas d'APK — build d'abord"
            build_apk
        fi
        install_apk
        launch_app ;;
esac

echo
echo "=== Terminé ==="
