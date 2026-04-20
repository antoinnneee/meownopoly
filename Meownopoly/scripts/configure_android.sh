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
# On force --target et --sysroot explicitement : le NDK r27 + CMake 3.30
# sur Asahi ne propage pas ces flags aux try_compile, d'où l'échec silencieux
# sous FEX. En les passant via CMAKE_{C,CXX}_COMPILER_TARGET + CMAKE_SYSROOT,
# tous les tests (compiler, Threads, etc.) reçoivent les bons flags.
ANDROID_SYSROOT="${ANDROID_NDK_ROOT:-$HOME/Android/Sdk/ndk/27.2.12479018}/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
ANDROID_TARGET="aarch64-linux-android28"

"$QT_CMAKE" \
    -S "$PROJECT_DIR" \
    -B "$BUILD_DIR" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DQT_HOST_PATH="$QT_HOST" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-28 \
    -DCMAKE_C_COMPILER_WORKS=1 \
    -DCMAKE_CXX_COMPILER_WORKS=1 \
    -DCMAKE_C_COMPILER_TARGET="$ANDROID_TARGET" \
    -DCMAKE_CXX_COMPILER_TARGET="$ANDROID_TARGET" \
    -DCMAKE_SYSROOT="$ANDROID_SYSROOT" \
    -DCMAKE_C_FLAGS_INIT="--target=$ANDROID_TARGET --sysroot=$ANDROID_SYSROOT" \
    -DCMAKE_CXX_FLAGS_INIT="--target=$ANDROID_TARGET --sysroot=$ANDROID_SYSROOT"

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
