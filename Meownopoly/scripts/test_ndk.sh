#!/bin/bash
# test_ndk.sh
# Test de cross-compilation du NDK Android vers aarch64 depuis l'host.
# Utile pour diagnostiquer les problèmes FEX/muvm sur Asahi Linux.
#
# Usage : bash Meownopoly/scripts/test_ndk.sh

set -u

NDK="${ANDROID_NDK_ROOT:-$HOME/Android/Sdk/ndk/27.2.12479018}"
SYSROOT="$NDK/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
CLANGXX="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++"
SRC="$HOME/t.cxx"
OBJ="$HOME/t.o"

echo "=== Test NDK cross-compile aarch64 ==="
echo "NDK    : $NDK"
echo "clang++: $CLANGXX"
echo

if [[ ! -x "$CLANGXX" ]]; then
    echo "ERREUR : clang++ introuvable à $CLANGXX"
    exit 1
fi

echo 'int main(){return 0;}' > "$SRC"
echo ">>> Fichier source : $SRC"
cat "$SRC"
echo

echo ">>> Compilation vers aarch64-linux-android28..."
"$CLANGXX" \
    --target=aarch64-linux-android28 \
    --sysroot="$SYSROOT" \
    -c "$SRC" -o "$OBJ"
RC=$?
echo "EXIT=$RC"
echo

if [[ $RC -eq 0 && -f "$OBJ" ]]; then
    echo ">>> Résultat :"
    file "$OBJ"
    echo
    echo "SUCCES : le NDK peut cross-compiler via FEX."
else
    echo "ECHEC : voir messages clang/ld au-dessus."
    exit $RC
fi

rm -f "$SRC" "$OBJ"
