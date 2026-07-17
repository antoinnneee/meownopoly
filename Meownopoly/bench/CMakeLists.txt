# ============================================================================
# meow_testbench — banc d'essai hors-process (doc/v3/12_BANC_ESSAI_R1.md,
# tâches A1/A2 du plan doc/v3/15_PLAN_IMPLEMENTATION.md).
#
# Exécutable Qt headless (lancé avec `-platform offscreen` au runtime par
# BenchSupervisor). Sources listées EXPLICITEMENT (pattern tests/CMakeLists.txt,
# pas le GLOB du jeu) : sous-ensemble strict — sérialisation map + hiérarchie
# Case + moteur physique cœur Pattounx v2.
#
# AUCUN module réseau lié (doc 12 §5) : pas de cpp/communication (Catway),
# pas de cpp/chat, pas de physics_session/physics_world/physics_worker, pas
# de cpp/automation, pas de game.cpp/game_session. Vérifié au 2026-07-17 :
#  - map.cpp / mapinfo.cpp / mapfilemanager.cpp : autonomes (Qt Core + logger)
#  - ItemSnapable.cpp → CaseFactory → hiérarchie Case → player.cpp (Case.cpp
#    inclut game/game.h mais n'en utilise aucun symbole → pas de game.cpp)
#  - decorationparameter.cpp → AssetManager (asset_manager.cpp +
#    metadata_generator.cpp, Qt Core/Gui/Qml uniquement, pas de réseau)
#  - pattounx_engine_v2.cpp / collision2d.cpp : cœur Qt-free (doc 12 §10)
# Le main du banc vit dans Meownopoly/bench/ (hors cpp/) pour ne PAS être
# ramassé par le file(GLOB_RECURSE cpp/*.cpp) du jeu.
# ============================================================================

set(MEOW_CPP "${CMAKE_CURRENT_SOURCE_DIR}/../cpp")

set(MEOW_BENCH_MAP_SOURCES
    # Headers Q_NAMESPACE sans .cpp associé : à lister explicitement pour
    # qu'AUTOMOC génère leur métaobjet (sinon undefined reference au link).
    "${MEOW_CPP}/game/map/maptypes.h"
    "${MEOW_CPP}/game/map/editdelta.h"
    "${MEOW_CPP}/game/map/map.cpp"
    "${MEOW_CPP}/game/map/mapinfo.cpp"
    "${MEOW_CPP}/game/map/mapfilemanager.cpp"
    "${MEOW_CPP}/game/map/playerprofile.cpp"
    "${MEOW_CPP}/game/map/screeneffect.cpp"
)

set(MEOW_BENCH_SNAPABLE_SOURCES
    "${MEOW_CPP}/game/item_snapable/ItemSnapable.cpp"
    "${MEOW_CPP}/game/item_snapable/itemsnapablefactory.cpp"
    "${MEOW_CPP}/game/item_snapable/Displayparameter.cpp"
    "${MEOW_CPP}/game/item_snapable/decorationparameter.cpp"
    "${MEOW_CPP}/game/item_snapable/ZoneParameter.cpp"
    "${MEOW_CPP}/game/item_snapable/npcparameter.cpp"
    "${MEOW_CPP}/game/item_snapable/enemyparameter.cpp"
    "${MEOW_CPP}/game/item_snapable/physicalobjectparameter.cpp"
)

set(MEOW_BENCH_CASE_SOURCES
    "${MEOW_CPP}/game/case/Case.cpp"
    "${MEOW_CPP}/game/case/CaseFactory.cpp"
    "${MEOW_CPP}/game/case/CaseCardBoardBox.cpp"
    "${MEOW_CPP}/game/case/CaseCatDevice.cpp"
    "${MEOW_CPP}/game/case/CaseCatDoor.cpp"
    "${MEOW_CPP}/game/case/CaseCatNip.cpp"
    "${MEOW_CPP}/game/case/CaseCatPerks.cpp"
    "${MEOW_CPP}/game/case/CaseFreeNap.cpp"
    "${MEOW_CPP}/game/case/CaseJail.cpp"
    "${MEOW_CPP}/game/case/CaseKibbleDispenser.cpp"
    "${MEOW_CPP}/game/case/CaseRestArea.cpp"
    "${MEOW_CPP}/game/case/CaseToJail.cpp"
    "${MEOW_CPP}/game/player.cpp"
)

set(MEOW_BENCH_PHYSICS_SOURCES
    "${MEOW_CPP}/game/physics/pattounx_engine_v2.cpp"
    "${MEOW_CPP}/game/physics/collision2d.cpp"
)

set(MEOW_BENCH_SUPPORT_SOURCES
    "${MEOW_CPP}/assetManager/asset_manager.cpp"
    "${MEOW_CPP}/tools/metadata_generator.cpp"
    "${MEOW_CPP}/tools/logger.cpp"
)

qt_add_executable(meow_testbench
    main.cpp
    bench_job.h
    bench_job.cpp
    bench_verdict.h
    bench_verdict.cpp
    bench_phases.h
    bench_phases.cpp
    rss_watchdog.h
    rss_watchdog.cpp
    ${MEOW_BENCH_MAP_SOURCES}
    ${MEOW_BENCH_SNAPABLE_SOURCES}
    ${MEOW_BENCH_CASE_SOURCES}
    ${MEOW_BENCH_PHYSICS_SOURCES}
    ${MEOW_BENCH_SUPPORT_SOURCES}
)

target_include_directories(meow_testbench PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${MEOW_CPP}"
    "${MEOW_CPP}/game"
    "${MEOW_CPP}/game/case"
    "${MEOW_CPP}/game/map"
    "${MEOW_CPP}/game/physics"
    "${MEOW_CPP}/game/item_snapable"
    "${MEOW_CPP}/tools"
    "${MEOW_CPP}/assetManager"
)

# Qml est requis par QQmlEngine::setObjectOwnership (ItemSnapable/factory) et
# les enregistrements QML des classes réutilisées ; Gui par QColor/QVector2D/
# QImageReader. Pas de Qt6::Network — garantie "pas de surface réseau" (§5).
target_link_libraries(meow_testbench PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
)

# Auto-surveillance RSS : GetProcessMemoryInfo (psapi) sur Windows.
if(WIN32)
    target_link_libraries(meow_testbench PRIVATE psapi)
endif()

# Sortie à côté de Meownopoly.exe : BenchSupervisor résout le banc par défaut
# dans applicationDirPath(), et les DLLs Qt déployées (windeployqt) y sont
# déjà. Les générateurs multi-config ajoutent le sous-dossier <CONFIG>.
set_target_properties(meow_testbench PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
)

# windeployqt (post-build du jeu) ne déploie que qwindows.dll : le plugin QPA
# offscreen requis par `-platform offscreen` doit être copié explicitement
# dans platforms/ à côté des exécutables.
if(WIN32 AND TARGET Qt6::QOffscreenIntegrationPlugin)
    add_custom_command(TARGET meow_testbench POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory
            "$<TARGET_FILE_DIR:meow_testbench>/platforms"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:Qt6::QOffscreenIntegrationPlugin>"
            "$<TARGET_FILE_DIR:meow_testbench>/platforms/"
        COMMENT "Déploiement du plugin QPA offscreen pour meow_testbench")
endif()
