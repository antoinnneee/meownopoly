# ============================================================================
# Tests cycle de vie de currentMap (Qt6::Test)
#
# Voir doc/architecture/MAP_LIFECYCLE.md pour l'analyse complète qui scope
# cette suite (variables centrales V1-V19, scénarios §A-§M, bugs G1-G10).
#
# v1 = tst_mapinfo : couvre MapInfo + PlayerProfile sans dépendance lourde.
#
# Différés : tst_mapfilemanager, tst_map_undoredo, tst_lifecycle. Ils
# dépendent transitivement de ItemSnapable→Case→game.h, qui n'est pas
# linkable en isolation sans refactor en object library CMake.
#
# Ce fichier se configure de deux façons :
#  1. Inclus depuis le top-level via `add_subdirectory(tests/map_lifecycle)` :
#     hérite des composants Qt6 du projet parent.
#  2. **Standalone** (pour environnements de dev où Quick3D + ShaderTools ne
#     sont pas installés mais Qt6::Test l'est) :
#       cmake -S tests/map_lifecycle -B build_map_tests -G Ninja
#       cmake --build build_map_tests
#       ctest --test-dir build_map_tests --output-on-failure
# ============================================================================

if (NOT TARGET Qt6::Test)
    # Mode standalone — projet racine indépendant du top-level Meownopoly.
    cmake_minimum_required(VERSION 3.21)
    project(map_lifecycle_tests LANGUAGES CXX)
    set(CMAKE_CXX_STANDARD 20)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)
    set(CMAKE_AUTOMOC ON)
    find_package(Qt6 REQUIRED COMPONENTS Core Test Qml)
    enable_testing()
    # En standalone, le test EST la cible du projet : on le veut dans `all`.
    set(_MAPTEST_EXCLUDE "")
else()
    # Inclus dans le top-level : hors du build générique `all` (compilé à la
    # demande via --target tst_mapinfo / map_lifecycle_tests / meownopoly_tests).
    set(_MAPTEST_EXCLUDE EXCLUDE_FROM_ALL)
endif()

set(MAP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../cpp/game/map")

qt_add_executable(tst_mapinfo ${_MAPTEST_EXCLUDE}
    tst_mapinfo.cpp
    "${MAP_DIR}/mapinfo.cpp"
    "${MAP_DIR}/playerprofile.cpp"
)
target_include_directories(tst_mapinfo PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/../../cpp"
    "${MAP_DIR}"
)
target_link_libraries(tst_mapinfo PRIVATE
    Qt6::Core Qt6::Test Qt6::Qml)
add_test(NAME tst_mapinfo COMMAND tst_mapinfo)

# Cible agrégée — calque le pattern `pattounx_tests`.
add_custom_target(map_lifecycle_tests
    DEPENDS tst_mapinfo
    COMMENT "Build all map lifecycle unit tests")
