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
# Sur Asahi aarch64 + FEX/muvm, CMake 3.30 ne peut pas compiler le fichier
# CMakeCXXCompilerId.cpp (clang NDK sort 248 silencieusement via émulation).
# Solution : pré-remplir *tous* les faits de détection dans le cache initial
# pour que CMake skip les try_compile qui plantent.
NDK_ROOT="${ANDROID_NDK_ROOT:-$HOME/Android/Sdk/ndk/27.2.12479018}"
NDK_BIN="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
NDK_SYSROOT="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
ANDROID_TARGET="aarch64-linux-android28"

# Cache initial pour skipper toute la détection
INIT_CACHE="$BUILD_DIR/init_cache.cmake"
mkdir -p "$BUILD_DIR"
cat > "$INIT_CACHE" <<CMAKE_EOF
# Bypass compiler detection (clang NDK plante via FEX sur ce test)
set(CMAKE_C_COMPILER_WORKS   TRUE  CACHE BOOL "" FORCE)
set(CMAKE_CXX_COMPILER_WORKS TRUE  CACHE BOOL "" FORCE)
set(CMAKE_C_COMPILER_FORCED   TRUE CACHE BOOL "" FORCE)
set(CMAKE_CXX_COMPILER_FORCED TRUE CACHE BOOL "" FORCE)

set(CMAKE_C_COMPILER_ID   "Clang" CACHE STRING "" FORCE)
set(CMAKE_CXX_COMPILER_ID "Clang" CACHE STRING "" FORCE)
set(CMAKE_C_COMPILER_VERSION   "18.0.3" CACHE STRING "" FORCE)
set(CMAKE_CXX_COMPILER_VERSION "18.0.3" CACHE STRING "" FORCE)
set(CMAKE_C_COMPILER_ID_RUN   TRUE CACHE BOOL "" FORCE)
set(CMAKE_CXX_COMPILER_ID_RUN TRUE CACHE BOOL "" FORCE)

# ABI facts (aarch64 LP64)
set(CMAKE_C_COMPILER_ABI   "ELF" CACHE STRING "" FORCE)
set(CMAKE_CXX_COMPILER_ABI "ELF" CACHE STRING "" FORCE)
set(CMAKE_C_SIZEOF_DATA_PTR   8 CACHE STRING "" FORCE)
set(CMAKE_CXX_SIZEOF_DATA_PTR 8 CACHE STRING "" FORCE)

# Threads : Android bionic a pthread dans libc, pas besoin de -lpthread
set(CMAKE_HAVE_LIBC_PTHREAD     TRUE CACHE BOOL "" FORCE)
set(CMAKE_USE_PTHREADS_INIT     TRUE CACHE BOOL "" FORCE)
set(THREADS_FOUND               TRUE CACHE BOOL "" FORCE)
set(Threads_FOUND               TRUE CACHE BOOL "" FORCE)
set(CMAKE_THREAD_LIBS_INIT      "" CACHE STRING "" FORCE)
set(THREADS_PREFER_PTHREAD_FLAG FALSE CACHE BOOL "" FORCE)
CMAKE_EOF

"$QT_CMAKE" \
    -S "$PROJECT_DIR" \
    -B "$BUILD_DIR" \
    -G Ninja \
    -C "$INIT_CACHE" \
    -DCMAKE_BUILD_TYPE=Release \
    -DQT_HOST_PATH="$QT_HOST" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-28 \
    -DCMAKE_C_COMPILER_TARGET="$ANDROID_TARGET" \
    -DCMAKE_CXX_COMPILER_TARGET="$ANDROID_TARGET" \
    -DCMAKE_SYSROOT="$NDK_SYSROOT" \
    -DCMAKE_C_FLAGS="--target=$ANDROID_TARGET --sysroot=$NDK_SYSROOT" \
    -DCMAKE_CXX_FLAGS="--target=$ANDROID_TARGET --sysroot=$NDK_SYSROOT"

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
