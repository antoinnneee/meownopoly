cmake_minimum_required(VERSION 3.21)

project(Meownopoly VERSION 1.0 LANGUAGES CXX)

# ============================================================================
# Configuration C++
# ============================================================================
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Activer les fonctionnalités automatiques de Qt
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# ============================================================================
# Trouver Qt6
# ============================================================================
find_package(Qt6 REQUIRED COMPONENTS
    Core
    Quick
    Qml
    Widgets
    QuickControls2
    Network
    Quick3D
    Sql
    WebSockets
    Concurrent
)

# Tests : optionnel (Qt6::Test pas toujours disponible selon l'install)
find_package(Qt6 QUIET COMPONENTS Test)

# CanvasPainter : optionnel (Tech Preview Qt 6.11+, indisponible avant).
# Quand présent, on compile le composant ZoneCanvasPainter (rendu GPU 2D
# via QRhi) et on définit MEOW_HAS_CANVAS_PAINTER pour le code C++ et QML.
find_package(Qt6 QUIET COMPONENTS CanvasPainter)

# HttpServer : add-on optionnel (D21, P0-1). Support la passerelle MCP
# streamable HTTP loopback intégrée au jeu (M1, AiGatewayServer). À installer
# via la Maintenance Tool sur le kit Qt 6.11.0 ; tant qu'absent, on définit
# MEOW_HAS_HTTP_SERVER=0 et le repli documenté est un pont stdio
# @modelcontextprotocol/sdk (patron automation_mcp/).
find_package(Qt6 QUIET COMPONENTS HttpServer)
# ============================================================================
# Collecter les fichiers sources
# ============================================================================
# Sources C++
file(GLOB_RECURSE SOURCES
    "${CMAKE_CURRENT_SOURCE_DIR}/cpp/*.cpp"
)

# Exclure les fichiers de test standalone de la bibliothèque reliable
# (test.cpp a son propre main() et requiert RELIABLE_ENABLE_TESTS=1)
list(FILTER SOURCES EXCLUDE REGEX ".*/reliable/test\\.cpp$")

# Exclure le main() du banc d'essai hors-process (meow_testbench, tâche A1) :
# il a son propre point d'entrée et n'appartient qu'à la cible meow_testbench
# (EXCLUDE_FROM_ALL, sources listées explicitement plus bas). Sans cette
# exclusion, le GLOB l'aspire dans l'exécutable principal → double `main`.
list(FILTER SOURCES EXCLUDE REGEX ".*/ai/bench/meow_testbench_main\\.cpp$")

# Exclure aussi le pipeline P1→P5 du banc (tâche A5) : il exécute du code
# candidat (hostile par défaut) et n'a de sens QUE dans le process jetable —
# le jeu ne doit jamais pouvoir instancier un artefact in-process par ce
# chemin. Le contexte restreint et la façade (cpp/ai/sandbox/), eux, RESTENT
# dans le jeu : code partagé banc/runtime (doc v3 12 §5, étage 2 D13).
list(FILTER SOURCES EXCLUDE REGEX ".*/ai/bench/bench_runner\\.cpp$")

# Headers C++
file(GLOB_RECURSE HEADERS
    "${CMAKE_CURRENT_SOURCE_DIR}/cpp/*.h"
)

# Exclure les outils standalone qui ont leur propre main() (aucun actuellement)
# list(FILTER SOURCES EXCLUDE REGEX ".*metadata_generator\\.cpp$")

# ============================================================================
# Fichiers de ressources Qt (.qrc)
# ============================================================================
set(QRC_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/qml.qrc
    ${CMAKE_CURRENT_SOURCE_DIR}/asset.qrc
    ${CMAKE_CURRENT_SOURCE_DIR}/base_comp.qrc
    ${CMAKE_CURRENT_SOURCE_DIR}/chat.qrc
    ${CMAKE_CURRENT_SOURCE_DIR}/launcher.qrc
    ${CMAKE_CURRENT_SOURCE_DIR}/other.qrc
)

# ============================================================================
# Créer l'exécutable
# ============================================================================
qt_add_executable(${PROJECT_NAME}
    ${SOURCES}
    ${HEADERS}
    ${QRC_FILES}
)

# ============================================================================
# Définitions de compilation
# ============================================================================
target_compile_definitions(${PROJECT_NAME} PRIVATE
    BUILD_DIR="${CMAKE_BINARY_DIR}"
    # Activer le mode debug de la lib reliable (logs détaillés, assertions)
    $<$<CONFIG:Debug>:RELIABLE_DEBUG>
)

# Configuration spécifique Android
if(ANDROID)
    set(ANDROID_VERSION_CODE 1)
    set(ANDROID_VERSION_NAME "1-indev")
    target_compile_definitions(${PROJECT_NAME} PRIVATE
        APP_VERSION_CODE="${ANDROID_VERSION_CODE}"
        APP_VERSION_NAME="${ANDROID_VERSION_NAME}"
    )
endif()

# ============================================================================
# Chemins d'inclusion
# ============================================================================
target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/case
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/map
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/physics
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/item_snapable
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/template
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/tools
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/tools/QtFolderCompressor
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/experiment
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/launcher
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/chat
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/account
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/assetManager
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/reliable
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/communication
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/network
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/modules
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/editor/network
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/editor/ops
)

# ============================================================================
# Lier les bibliothèques Qt
# ============================================================================
target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::Qml
    Qt6::Widgets
    Qt6::QuickControls2
    Qt6::Network
    Qt6::Quick3D
    Qt6::Sql
    Qt6::WebSockets
    Qt6::Concurrent
)

# Lien + flag pour le composant ZoneCanvasPainter quand le module est dispo.
if (TARGET Qt6::CanvasPainter)
    target_link_libraries(${PROJECT_NAME} PRIVATE Qt6::CanvasPainter)
    target_compile_definitions(${PROJECT_NAME} PRIVATE MEOW_HAS_CANVAS_PAINTER)
    message(STATUS "Qt6::CanvasPainter trouvé — ZoneCanvasPainter activé.")
else()
    message(STATUS "Qt6::CanvasPainter absent (nécessite Qt 6.11+) — ZoneCanvasPainter désactivé.")
endif()

# Lien + flag pour la passerelle MCP streamable HTTP (D21) quand l'add-on
# QtHttpServer est installé. Absent = repli pont stdio documenté (P0-1).
if (TARGET Qt6::HttpServer)
    target_link_libraries(${PROJECT_NAME} PRIVATE Qt6::HttpServer)
    target_compile_definitions(${PROJECT_NAME} PRIVATE MEOW_HAS_HTTP_SERVER=1)
    message(STATUS "Qt6::HttpServer trouvé — passerelle MCP streamable HTTP activée.")
else()
    target_compile_definitions(${PROJECT_NAME} PRIVATE MEOW_HAS_HTTP_SERVER=0)
    message(STATUS "Qt6::HttpServer absent (add-on à installer via Maintenance Tool) — repli pont stdio (automation_mcp/).")
endif()

# ============================================================================
# Chemins d'import QML (pour Qt Creator et le code model)
# ============================================================================
set(QML_IMPORT_PATH 
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/qml
    ${CMAKE_CURRENT_SOURCE_DIR}/qml/editor/moduleManager/
    ${CMAKE_CURRENT_SOURCE_DIR}/qml/editor/configPanel/
    CACHE STRING "QML Import Path" FORCE
)

# ============================================================================
# Configuration de déploiement (portable Windows / Linux)
# ============================================================================
# Le déploiement des plugins QML / Quick3D (+ CanvasPainter s'il est présent —
# voir la détection optionnelle Qt6::CanvasPainter plus haut) est spécifique à
# l'OS. Sous Windows on s'appuie sur windeployqt (fourni avec le kit). Sous
# Linux, en développement, l'exécutable tourne directement contre le Qt installé
# et aucun bundling n'est requis ; pour produire un paquet redistribuable on
# passe un outil externe optionnel via -DMEOW_LINUX_DEPLOY_TOOL=...
# L'absence de Qt6::CanvasPainter (kit Linux sans le module Tech Preview) est
# gérée en amont (find_package QUIET + garde TARGET) et n'empêche ni le build ni
# le déploiement des plugins QML/Quick3D standards.
if(WIN32)
    find_program(WINDEPLOYQT windeployqt HINTS "${Qt6_DIR}/../../../bin")
    file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/deploy_$<CONFIG>.bat"
        CONTENT "$<IF:$<CONFIG:Release>,\"${WINDEPLOYQT}\" \"$<TARGET_FILE:${PROJECT_NAME}>\" --qmldir \"${CMAKE_CURRENT_SOURCE_DIR}/qml\" --no-translations,@echo Deploy skipped (not Release)>"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND "${CMAKE_BINARY_DIR}/deploy_$<CONFIG>.bat"
        COMMENT "Running windeployqt (Release only)..."
    )
elseif(UNIX AND NOT APPLE)
    set(MEOW_LINUX_DEPLOY_TOOL "" CACHE FILEPATH
        "Outil de déploiement Linux optionnel (linuxdeployqt, cqtdeployer...). Vide = pas de bundling (exécution contre le Qt installé).")
    if(MEOW_LINUX_DEPLOY_TOOL)
        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
            COMMAND "${MEOW_LINUX_DEPLOY_TOOL}" "$<TARGET_FILE:${PROJECT_NAME}>" "-qmldir=${CMAKE_CURRENT_SOURCE_DIR}/qml"
            COMMENT "Déploiement Linux via ${MEOW_LINUX_DEPLOY_TOOL}..."
            VERBATIM
        )
    else()
        message(STATUS "Déploiement Linux : aucun MEOW_LINUX_DEPLOY_TOOL défini — exécution contre le Qt installé (pas de bundling).")
    endif()
endif()

# Android : le module android_openssl est fourni hors de l'arbre et son chemin
# dépend de la machine. On le paramètre par variable CMake ou d'environnement
# ANDROID_OPENSSL_ROOT (dossier contenant son CMakeLists.txt) — plus de chemin
# utilisateur absolu en dur dans ce fichier.
if (ANDROID)
    set(ANDROID_OPENSSL_ROOT "" CACHE PATH
        "Dossier du module android_openssl (contenant CMakeLists.txt). Réglable via -DANDROID_OPENSSL_ROOT=... ou la variable d'environnement du même nom.")
    if(NOT ANDROID_OPENSSL_ROOT AND DEFINED ENV{ANDROID_OPENSSL_ROOT})
        set(ANDROID_OPENSSL_ROOT "$ENV{ANDROID_OPENSSL_ROOT}")
    endif()

    if(ANDROID_OPENSSL_ROOT AND EXISTS "${ANDROID_OPENSSL_ROOT}/CMakeLists.txt")
        include("${ANDROID_OPENSSL_ROOT}/CMakeLists.txt")
    else()
        message(WARNING "android_openssl introuvable : définissez ANDROID_OPENSSL_ROOT (variable CMake ou d'environnement) vers le dossier contenant son CMakeLists.txt.")
    endif()
endif()

# Outil standalone : Metadata Generator (désormais intégré au projet principal)
# option(BUILD_METADATA_GENERATOR "Build the standalone metadata generator tool" OFF)

# if(BUILD_METADATA_GENERATOR)
#     qt_add_executable(metadata_generator
#         ${CMAKE_CURRENT_SOURCE_DIR}/cpp/tools/metadata_generator.cpp
#     )
#     
#     target_link_libraries(metadata_generator PRIVATE
#         Qt6::Core
#         Qt6::Gui
#     )
#     
#     message(STATUS "Metadata Generator tool will be built")
# endif()

# ============================================================================
# Target de test P2P dual-instance (portable Windows / Linux)
# ============================================================================
# Lance deux instances du jeu (Instance 1 + Instance 2 avec `--instance 2`).
# Windows : `cmd /c start` ouvre chaque instance dans sa propre console détachée.
# Linux/macOS : un petit script shell (scripts/dual_test_p2p.sh) lance les deux
# processus en arrière-plan (`&`) — équivalent portable sans dépendance à `start`.
if(WIN32)
    add_custom_target(dual_test_p2p
        COMMAND cmd /c start "Meownopoly - Instance 1" "$<TARGET_FILE:${PROJECT_NAME}>"
        COMMAND ${CMAKE_COMMAND} -E sleep 2
        COMMAND cmd /c start "Meownopoly - Instance 2" "$<TARGET_FILE:${PROJECT_NAME}>" --instance 2
        DEPENDS ${PROJECT_NAME}
        COMMENT "Lancement du test P2P dual-instance..."
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )
else()
    add_custom_target(dual_test_p2p
        COMMAND ${CMAKE_COMMAND} -E env bash
            "${CMAKE_CURRENT_SOURCE_DIR}/scripts/dual_test_p2p.sh"
            "$<TARGET_FILE:${PROJECT_NAME}>"
        DEPENDS ${PROJECT_NAME}
        COMMENT "Lancement du test P2P dual-instance..."
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        VERBATIM
    )
endif()

# ============================================================================
# Banc d'essai hors-process (meow_testbench, D26 / doc v3 12) — tâche A1
# ============================================================================
# Exécutable jetable HEADLESS (-platform offscreen) qui rejoue tout artefact
# QML/JS candidat avant son introduction en partie. Il réutilise l'arbre
# source du jeu mais avec des sources LISTÉES EXPLICITEMENT (pas le GLOB) :
# sérialisation de map + ItemSnapableFactory + cœur physique Pattounx v2
# (Qt-free) + les types QML nécessaires. AUCUN module réseau n'est lié
# (pas de Catway/chat/PhysicsSession/automation) — ceinture et bretelles avec
# le préfiltre P0 (doc 12 §5). Liste calculée par clôture des #include du
# cluster map/case/item_snapable/game (aucune dépendance réseau).
#
# Construction à la demande (EXCLUDE_FROM_ALL — un build générique l'ignore) :
#   cmake --build build --config Release --target meow_testbench
set(MEOW_TESTBENCH_SOURCES
    # Point d'entrée du banc
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/ai/bench/meow_testbench_main.cpp
    # Contrat job/verdict partagé avec le superviseur côté jeu (tâche A2)
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/ai/bench/bench_protocol.cpp
    # Pipeline P1→P5 (tâche A5) — exclu du GLOB de l'exécutable principal
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/ai/bench/bench_runner.cpp
    # Contexte restreint + façade Meow.GameApi (tâche A6) — code PARTAGÉ
    # banc/jeu (doc 12 §5) : ces deux fichiers sont aussi dans le GLOB du jeu
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/ai/sandbox/restricted_context.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/ai/sandbox/meow_game_api.cpp
    # Préfiltre statique P0 (tâche A4) — code PARTAGÉ banc/jeu : le mode
    # `--static-check` du banc rejoue le P0 pour le harnais de corpus (A7)
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/ai/sandbox/static_validator.cpp
    # Sérialisation de map + gestionnaires de fichiers
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/map/map.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/map/mapfilemanager.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/map/mapinfo.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/map/playerprofile.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/map/screeneffect.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/map/templatefilemanager.cpp
    # maptypes.h porte un Q_NAMESPACE (enum MapType) sans .cpp associé —
    # listé explicitement pour qu'AUTOMOC génère son staticMetaObject.
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/map/maptypes.h
    # ItemSnapable + fabrique + sous-paramètres
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/item_snapable/ItemSnapable.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/item_snapable/itemsnapablefactory.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/item_snapable/Displayparameter.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/item_snapable/decorationparameter.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/item_snapable/ZoneParameter.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/item_snapable/npcparameter.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/item_snapable/enemyparameter.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/item_snapable/physicalobjectparameter.cpp
    # Joueur + hiérarchie de cases (le singleton Game n'est PAS lié : il est
    # couplé au réseau via game_loader → EditorOpBus → EditorSession, alors que
    # le cluster map/case/item_snapable ne le référence qu'en en-tête ; la
    # reconstruction de snapshot passe par Map + ItemSnapableFactory, doc 12 §10)
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/player.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/case/Case.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/case/CaseFactory.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/case/CaseCardBoardBox.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/case/CaseCatDevice.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/case/CaseCatDoor.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/case/CaseCatNip.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/case/CaseCatPerks.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/case/CaseFreeNap.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/case/CaseJail.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/case/CaseKibbleDispenser.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/case/CaseRestArea.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/case/CaseToJail.cpp
    # Cœur physique Pattounx v2 (Qt-free, sans worker ni PhysicsSession)
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/physics/pattounx_engine_v2.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/physics/collision2d.cpp
    # Gestion d'assets (référencée par decorationparameter) + son générateur de
    # métadonnées + logger
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/assetManager/asset_manager.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/tools/metadata_generator.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/tools/logger.cpp
)

qt_add_executable(meow_testbench EXCLUDE_FROM_ALL
    ${MEOW_TESTBENCH_SOURCES}
)

target_include_directories(meow_testbench PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/case
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/map
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/physics
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/game/item_snapable
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/tools
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp/assetManager
)

# Aucun module réseau : Core + Gui + Qml suffisent (types QObject, pas de
# QQuickItem ni de Widgets dans le cluster ; offscreen forcé au runtime).
target_link_libraries(meow_testbench PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
)

# Le jeu embarque le superviseur du banc (BenchSupervisor cherche
# meow_testbench à côté de l'exe) : construire le jeu construit donc aussi le
# banc, sinon tout build tree qui n'a jamais invoqué la cible à la main
# (ex. Qt Creator) rend des verdicts « exécutable du banc introuvable ».
add_dependencies(${PROJECT_NAME} meow_testbench)

# ============================================================================
# Tests unitaires (PattounX)
# ============================================================================
option(MEOWNOPOLY_BUILD_TESTS "Build PattounX unit tests" ON)

if(MEOWNOPOLY_BUILD_TESTS AND Qt6Test_FOUND)
    enable_testing()
    add_subdirectory(tests)
elseif(MEOWNOPOLY_BUILD_TESTS)
    message(STATUS "Qt6::Test introuvable — tests désactivés")
endif()

# ============================================================================
# Messages d'information
# ============================================================================
message(STATUS "")
message(STATUS "=== Meownopoly CMake Configuration ===")
message(STATUS "Qt Version: ${Qt6_VERSION}")
message(STATUS "C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "Source Directory: ${CMAKE_CURRENT_SOURCE_DIR}")
message(STATUS "Build Directory: ${CMAKE_BINARY_DIR}")
message(STATUS "")
