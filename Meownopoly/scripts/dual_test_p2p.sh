#!/usr/bin/env bash
# ============================================================================
# dual_test_p2p.sh — équivalent portable (Linux/macOS) de la cible CMake
# Windows `dual_test_p2p` qui repose sur `cmd /c start`.
#
# Lance deux instances du jeu :
#   - Instance 1 (par défaut)
#   - Instance 2 (avec `--instance 2` → applicationName distinct → dossiers
#     AppDataLocation séparés, cf. main.cpp).
#
# Usage : dual_test_p2p.sh <chemin_executable_Meownopoly>
# Appelé par la cible CMake `dual_test_p2p` (voir CMakeLists.txt). Le répertoire
# de travail est fixé par CMake (WORKING_DIRECTORY ${CMAKE_BINARY_DIR}).
# ============================================================================
set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <chemin_executable_Meownopoly>" >&2
    exit 1
fi

EXE="$1"
if [ ! -x "$EXE" ]; then
    echo "Erreur : exécutable introuvable ou non exécutable : $EXE" >&2
    exit 1
fi

echo "Lancement de l'Instance 1..."
"$EXE" &
PID1=$!

# Laisser l'Instance 1 s'initialiser avant de démarrer la seconde (parité avec
# le `cmake -E sleep 2` de la cible Windows).
sleep 2

echo "Lancement de l'Instance 2 (--instance 2)..."
"$EXE" --instance 2 &
PID2=$!

echo "Instances lancées (PID1=$PID1, PID2=$PID2). Elles tournent en arrière-plan."
