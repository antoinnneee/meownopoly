#!/bin/bash
# configure_android.sh
# Configure le build Android de Meownopoly avec qt-cmake + NDK r27.
# Bypass le test compiler CMake (qui plante sous FEX/muvm sur Asahi
# parce qu'il n'injecte pas --target=aarch64-linux-android28).
#
# Usage :
#   bash Meownopoly/scripts/configure_android.sh        # reconfigure from scratch
#   bash Meownopoly/scripts/configure_android.sh build  # reconfigure + build

set -euo pipefail

# --- Chemins ----------------------------------------------------------------
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$(dirname "$PROJECT_DIR")/build-android"

QT_ANDROID="${QT_ANDROID_PATH:-$HOME/Qt/6.10.3/android_arm64_v8a}"
QT_HOST="${QT_HOST_PATH:-$HOME/Qt/6.10.3/gcc_arm64}"
QT_CMAKE="$QT_ANDROID/bin/qt-cmake"

# --- Sanity checks ----------------------------------------------------------
[[ -x "$QT_CMAKE" ]] || { echo "qt-cmake introuvable : $QT_CMAKE"; exit 1; }
[[ -d "$QT_HOST/bin" ]] || { echo "Host Qt introuvable : $QT_HOST"; exit 1; }

echo "=== Configuration build Android ==="
echo "Project : $PROJECT_DIR"
echo "Build   : $BUILD_DIR"
echo "Qt host : $QT_HOST"
echo "Qt cible: $QT_ANDROID"
echo

# --- Clean ------------------------------------------------------------------
rm -rf "$BUILD_DIR"

# --- Configure --------------------------------------------------------------
# CMake 3.30 + NDK r27 sur Asahi : CMAKE_CXX_COMPILER_TARGET est bien défini
# par le toolchain mais n'atteint pas la phase de détection d'ABI ni les
# try_compile, d'où les échecs silencieux sous FEX. Contournement robuste :
# utiliser les wrappers NDK aarch64-linux-android28-clang{,++} qui injectent
# --target et --sysroot eux-mêmes, indépendamment de CMake.
NDK_BIN="${ANDROID_NDK_ROOT:-$HOME/Android/Sdk/ndk/27.2.12479018}/toolchains/llvm/prebuilt/linux-x86_64/bin"
CC_WRAPPER="$NDK_BIN/aarch64-linux-android28-clang"
CXX_WRAPPER="$NDK_BIN/aarch64-linux-android28-clang++"

[[ -x "$CC_WRAPPER" ]] || { echo "Wrapper C introuvable : $CC_WRAPPER"; exit 1; }
[[ -x "$CXX_WRAPPER" ]] || { echo "Wrapper C++ introuvable : $CXX_WRAPPER"; exit 1; }

"$QT_CMAKE" \
    -S "$PROJECT_DIR" \
    -B "$BUILD_DIR" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DQT_HOST_PATH="$QT_HOST" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-28 \
    -DCMAKE_C_COMPILER="$CC_WRAPPER" \
    -DCMAKE_CXX_COMPILER="$CXX_WRAPPER" \
    -DCMAKE_C_COMPILER_WORKS=1 \
    -DCMAKE_CXX_COMPILER_WORKS=1

echo
echo "=== Configuration OK. Build dir : $BUILD_DIR ==="

# --- Build optionnel --------------------------------------------------------
if [[ "${1:-}" == "build" ]]; then
    echo
    echo "=== Build ==="
    cmake --build "$BUILD_DIR" 2>&1 | tee /tmp/meow-android-build.log
    echo
    echo "=== Build fini (log : /tmp/meow-android-build.log) ==="
fi
