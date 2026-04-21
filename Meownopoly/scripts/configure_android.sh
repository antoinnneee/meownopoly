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

# --- Clean (seulement si --clean ou première config) -----------------------
# ATTENTION : ne PAS wiper le build dir par défaut ! On veut que les builds
# soient incrémentaux (box64 interpréter = 1-2h pour from-scratch).
#   ./configure_android.sh            → reconfigure si pas de CMakeCache, sinon skip
#   ./configure_android.sh build      → build incrémental (reconfigure si besoin)
#   ./configure_android.sh clean      → wipe + reconfigure from scratch
#   ./configure_android.sh clean build → wipe + reconfigure + build
NEED_CONFIGURE=1
NEED_BUILD=0
for arg in "$@"; do
    case "$arg" in
        clean) rm -rf "$BUILD_DIR"; echo "=== Build dir wiped ===" ;;
        build) NEED_BUILD=1 ;;
    esac
done
if [[ -f "$BUILD_DIR/CMakeCache.txt" && ! " $* " =~ " clean " ]]; then
    NEED_CONFIGURE=0
    echo "=== Cache CMake existant → skip reconfigure (use 'clean' pour forcer) ==="
fi

# --- Configure --------------------------------------------------------------
# Sur Asahi aarch64 + FEX/muvm, CMake 3.30 ne peut pas compiler le fichier
# CMakeCXXCompilerId.cpp (clang NDK sort 248 silencieusement via émulation).
# Solution : pré-remplir *tous* les faits de détection dans le cache initial
# pour que CMake skip les try_compile qui plantent.
NDK_ROOT="${ANDROID_NDK_ROOT:-$HOME/Android/Sdk/ndk/27.2.12479018}"
NDK_BIN="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
NDK_SYSROOT="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
ANDROID_TARGET="aarch64-linux-android28"

# Crée un répertoire "clean" d'includes EGL/GLES/vulkan sans les headers C.
# Objectif : donner à find_package(EGL) un INCLUDE_DIR valide qui contient
# EGL/*, GLES2/*, GLES3/*, vulkan/* mais PAS stdint.h etc., ce qui évite
# d'ajouter sysroot/usr/include comme -isystem (qui court-circuite libc++).
GFX_INCLUDE="$HOME/android-gfx-include"
if [[ ! -d "$GFX_INCLUDE/EGL" ]]; then
    mkdir -p "$GFX_INCLUDE"
    for sub in EGL GLES GLES2 GLES3 vulkan KHR; do
        if [[ -d "$NDK_SYSROOT/usr/include/$sub" ]]; then
            ln -sfn "$NDK_SYSROOT/usr/include/$sub" "$GFX_INCLUDE/$sub"
        fi
    done
fi

# Cache initial pour skipper toute la détection
INIT_CACHE="$BUILD_DIR/init_cache.cmake"
mkdir -p "$BUILD_DIR"
if [[ $NEED_CONFIGURE -eq 1 ]]; then
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

# Standards par défaut de clang 18 (= gnu17 / gnu++17)
set(CMAKE_C_STANDARD_COMPUTED_DEFAULT       "17" CACHE STRING "" FORCE)
set(CMAKE_CXX_STANDARD_COMPUTED_DEFAULT     "17" CACHE STRING "" FORCE)
set(CMAKE_C_EXTENSIONS_COMPUTED_DEFAULT     "ON" CACHE STRING "" FORCE)
set(CMAKE_CXX_EXTENSIONS_COMPUTED_DEFAULT   "ON" CACHE STRING "" FORCE)

# Features supportées par Clang 18 — liste complète car CMake check des
# features granulaires (cxx_decltype, cxx_constexpr, etc.) pas seulement std.
set(CMAKE_C_COMPILE_FEATURES
    "c_std_90;c_std_99;c_std_11;c_std_17;c_std_23;c_function_prototypes;c_restrict;c_static_assert;c_variadic_macros"
    CACHE STRING "" FORCE)
set(CMAKE_C90_COMPILE_FEATURES "c_std_90;c_function_prototypes" CACHE STRING "" FORCE)
set(CMAKE_C99_COMPILE_FEATURES "c_std_99;c_restrict;c_variadic_macros" CACHE STRING "" FORCE)
set(CMAKE_C11_COMPILE_FEATURES "c_std_11;c_static_assert" CACHE STRING "" FORCE)
set(CMAKE_C17_COMPILE_FEATURES "c_std_17" CACHE STRING "" FORCE)
set(CMAKE_C23_COMPILE_FEATURES "c_std_23" CACHE STRING "" FORCE)

set(CMAKE_CXX_COMPILE_FEATURES
    "cxx_std_98;cxx_std_11;cxx_std_14;cxx_std_17;cxx_std_20;cxx_std_23;cxx_std_26;cxx_template_template_parameters;cxx_alias_templates;cxx_alignas;cxx_alignof;cxx_attributes;cxx_auto_type;cxx_constexpr;cxx_decltype;cxx_decltype_incomplete_return_types;cxx_default_function_template_args;cxx_defaulted_functions;cxx_defaulted_move_initializers;cxx_delegating_constructors;cxx_deleted_functions;cxx_enum_forward_declarations;cxx_explicit_conversions;cxx_extended_friend_declarations;cxx_extern_templates;cxx_final;cxx_func_identifier;cxx_generalized_initializers;cxx_inheriting_constructors;cxx_inline_namespaces;cxx_lambdas;cxx_local_type_template_args;cxx_long_long_type;cxx_noexcept;cxx_nonstatic_member_init;cxx_nullptr;cxx_override;cxx_range_for;cxx_raw_string_literals;cxx_reference_qualified_functions;cxx_right_angle_brackets;cxx_rvalue_references;cxx_sizeof_member;cxx_static_assert;cxx_strong_enums;cxx_thread_local;cxx_trailing_return_types;cxx_unicode_literals;cxx_uniform_initialization;cxx_unrestricted_unions;cxx_user_literals;cxx_variadic_macros;cxx_variadic_templates;cxx_aggregate_default_initializers;cxx_attribute_deprecated;cxx_binary_literals;cxx_contextual_conversions;cxx_decltype_auto;cxx_digit_separators;cxx_generic_lambdas;cxx_lambda_init_captures;cxx_relaxed_constexpr;cxx_return_type_deduction;cxx_variable_templates"
    CACHE STRING "" FORCE)

set(CMAKE_CXX98_COMPILE_FEATURES "cxx_std_98;cxx_template_template_parameters" CACHE STRING "" FORCE)
set(CMAKE_CXX11_COMPILE_FEATURES "cxx_std_11;cxx_alias_templates;cxx_alignas;cxx_alignof;cxx_attributes;cxx_auto_type;cxx_constexpr;cxx_decltype;cxx_decltype_incomplete_return_types;cxx_default_function_template_args;cxx_defaulted_functions;cxx_defaulted_move_initializers;cxx_delegating_constructors;cxx_deleted_functions;cxx_enum_forward_declarations;cxx_explicit_conversions;cxx_extended_friend_declarations;cxx_extern_templates;cxx_final;cxx_func_identifier;cxx_generalized_initializers;cxx_inheriting_constructors;cxx_inline_namespaces;cxx_lambdas;cxx_local_type_template_args;cxx_long_long_type;cxx_noexcept;cxx_nonstatic_member_init;cxx_nullptr;cxx_override;cxx_range_for;cxx_raw_string_literals;cxx_reference_qualified_functions;cxx_right_angle_brackets;cxx_rvalue_references;cxx_sizeof_member;cxx_static_assert;cxx_strong_enums;cxx_thread_local;cxx_trailing_return_types;cxx_unicode_literals;cxx_uniform_initialization;cxx_unrestricted_unions;cxx_user_literals;cxx_variadic_macros;cxx_variadic_templates" CACHE STRING "" FORCE)
set(CMAKE_CXX14_COMPILE_FEATURES "cxx_std_14;cxx_aggregate_default_initializers;cxx_attribute_deprecated;cxx_binary_literals;cxx_contextual_conversions;cxx_decltype_auto;cxx_digit_separators;cxx_generic_lambdas;cxx_lambda_init_captures;cxx_relaxed_constexpr;cxx_return_type_deduction;cxx_variable_templates" CACHE STRING "" FORCE)
set(CMAKE_CXX17_COMPILE_FEATURES "cxx_std_17" CACHE STRING "" FORCE)
set(CMAKE_CXX20_COMPILE_FEATURES "cxx_std_20" CACHE STRING "" FORCE)
set(CMAKE_CXX23_COMPILE_FEATURES "cxx_std_23" CACHE STRING "" FORCE)
set(CMAKE_CXX26_COMPILE_FEATURES "cxx_std_26" CACHE STRING "" FORCE)

# Threads : Android bionic a pthread dans libc, pas besoin de -lpthread
set(CMAKE_HAVE_LIBC_PTHREAD     TRUE CACHE BOOL "" FORCE)
set(CMAKE_USE_PTHREADS_INIT     TRUE CACHE BOOL "" FORCE)
set(THREADS_FOUND               TRUE CACHE BOOL "" FORCE)
set(Threads_FOUND               TRUE CACHE BOOL "" FORCE)
set(CMAKE_THREAD_LIBS_INIT      "" CACHE STRING "" FORCE)
set(THREADS_PREFER_PTHREAD_FLAG FALSE CACHE BOOL "" FORCE)

# Atomic (stdatomic dans libc sur Android)
set(HAVE_STDATOMIC           TRUE CACHE BOOL "" FORCE)
set(HAVE_STDATOMIC_WITH_LIB  TRUE CACHE BOOL "" FORCE)

# EGL / GLES : présents dans le sysroot NDK (libEGL.so, libGLESv2.so)
# check_cxx_source_compiles plante sur link stage via FEX → on bypass
set(HAVE_EGL                 TRUE CACHE BOOL "" FORCE)
set(HAVE_GLESv2              TRUE CACHE BOOL "" FORCE)
set(HAVE_GLESv3              TRUE CACHE BOOL "" FORCE)
set(HAVE_OPENGL_ES_2         TRUE CACHE BOOL "" FORCE)
set(HAVE_OPENGL_ES_3         TRUE CACHE BOOL "" FORCE)

# Ne PAS ajouter sysroot/usr/include comme -isystem : les headers NDK sont
# déjà résolus par clang via --target + --sysroot, et si on les ajoute
# explicitement ils court-circuitent libc++ (cstdint cherche libc++/stdint.h
# mais trouve le C stdint.h d'abord).
# EGL.h et GLES[23]/gl*.h sont dans <sysroot>/usr/include/EGL/ et /GLES2,
# mais clang les résout sans besoin d'-isystem explicite.
set(EGL_INCLUDE_DIR              "$GFX_INCLUDE" CACHE PATH "" FORCE)
set(GLESv2_INCLUDE_DIR           "$GFX_INCLUDE" CACHE PATH "" FORCE)
set(Vulkan_INCLUDE_DIR           "$GFX_INCLUDE" CACHE PATH "" FORCE)
set(VulkanHeaders_INCLUDE_DIR    "$GFX_INCLUDE" CACHE PATH "" FORCE)
set(WrapVulkanHeaders_INCLUDE_DIR "$GFX_INCLUDE" CACHE PATH "" FORCE)
# Libraries aussi — pointer directement sur le .so évite search path parasite
set(EGL_LIBRARY     "$NDK_SYSROOT/usr/lib/aarch64-linux-android/28/libEGL.so" CACHE FILEPATH "" FORCE)
set(GLESv2_LIBRARY  "$NDK_SYSROOT/usr/lib/aarch64-linux-android/28/libGLESv2.so" CACHE FILEPATH "" FORCE)
CMAKE_EOF

"$QT_CMAKE" \
    -S "$PROJECT_DIR" \
    -B "$BUILD_DIR" \
    -G Ninja \
    -C "$INIT_CACHE" \
    -DCMAKE_BUILD_TYPE=Release \
    -DQT_HOST_PATH="$QT_HOST" \
    -DANDROID_ABI=arm64-v8a \
    -DQT_ANDROID_ABIS=arm64-v8a \
    -DANDROID_PLATFORM=android-28 \
    -DCMAKE_C_COMPILER_TARGET="$ANDROID_TARGET" \
    -DCMAKE_CXX_COMPILER_TARGET="$ANDROID_TARGET" \
    -DCMAKE_SYSROOT="$NDK_SYSROOT" \
    -DCMAKE_C_FLAGS="--target=$ANDROID_TARGET --sysroot=$NDK_SYSROOT" \
    -DCMAKE_CXX_FLAGS="--target=$ANDROID_TARGET --sysroot=$NDK_SYSROOT -cxx-isystem $NDK_SYSROOT/usr/include/c++/v1"
fi  # NEED_CONFIGURE

echo
echo "=== Configuration OK. Build dir : $BUILD_DIR ==="

# --- Build optionnel --------------------------------------------------------
if [[ $NEED_BUILD -eq 1 ]]; then
    echo
    echo "=== Build (j=1 pour éviter les plantages concurrents muvm/FEX) ==="
    # Parallélisme = 1 obligatoire sur Asahi : le serveur muvm ne supporte
    # pas plusieurs clients x86_64 concurrents (ECONNREFUSED / ENOENT socket).
    # Override possible : MEOW_JOBS=4 bash configure_android.sh build.
    JOBS="${MEOW_JOBS:-1}"
    cmake --build "$BUILD_DIR" -j "$JOBS" 2>&1 | tee /tmp/meow-android-build.log
    echo
    echo "=== Build fini (log : /tmp/meow-android-build.log) ==="
fi
