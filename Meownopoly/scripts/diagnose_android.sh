#!/bin/bash
# diagnose_android.sh
# Lance un CMakeLists minimal via qt-cmake pour voir quels flags
# sont réellement passés au clang et où le NDK résoud son sysroot.
#
# Usage : bash Meownopoly/scripts/diagnose_android.sh

set -u

NDK="${ANDROID_NDK_ROOT:-$HOME/Android/Sdk/ndk/27.2.12479018}"
QT_ANDROID="${QT_ANDROID_PATH:-$HOME/Qt/6.10.3/android_arm64_v8a}"
QT_HOST="${QT_HOST_PATH:-$HOME/Qt/6.10.3/gcc_arm64}"

echo "=== Diagnostic Android toolchain ==="
echo "NDK : $NDK"
echo "Host arch : $(uname -m)"
echo

# Vérif prebuilt host dir
echo "=== NDK prebuilt dirs ==="
ls "$NDK/toolchains/llvm/prebuilt/"
echo
echo "=== Sysroot visible ==="
ls -d "$NDK/toolchains/llvm/prebuilt/linux-x86_64/sysroot" 2>/dev/null || echo "PAS x86_64"
ls -d "$NDK/toolchains/llvm/prebuilt/linux-aarch64/sysroot" 2>/dev/null || echo "PAS aarch64"
echo

# Crée un mini projet
TMP="$(mktemp -d)"
cat > "$TMP/CMakeLists.txt" <<'CML'
cmake_minimum_required(VERSION 3.22)
project(diag LANGUAGES NONE)

message(STATUS "HOST=${CMAKE_HOST_SYSTEM_NAME} proc=${CMAKE_HOST_SYSTEM_PROCESSOR}")
message(STATUS "ANDROID_HOST_TAG=${ANDROID_HOST_TAG}")
message(STATUS "ANDROID_NDK_HOST_TAG=${ANDROID_NDK_HOST_TAG}")
message(STATUS "ANDROID_TOOLCHAIN_ROOT=${ANDROID_TOOLCHAIN_ROOT}")
message(STATUS "CMAKE_SYSROOT=${CMAKE_SYSROOT}")
message(STATUS "CMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}")
message(STATUS "CMAKE_CXX_COMPILER_TARGET=${CMAKE_CXX_COMPILER_TARGET}")
message(STATUS "CMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS}")
CML

rm -rf "$TMP/build"
echo "=== qt-cmake minimal run ==="
"$QT_ANDROID/bin/qt-cmake" \
    -S "$TMP" \
    -B "$TMP/build" \
    -DQT_HOST_PATH="$QT_HOST" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-28 \
    2>&1 | grep -E "^-- " | head -30

rm -rf "$TMP"
