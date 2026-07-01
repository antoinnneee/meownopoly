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
# Configuration de déploiement (portable Windows)
# ============================================================================
if(WIN32)
    find_program(WINDEPLOYQT windeployqt HINTS "${Qt6_DIR}/../../../bin")
    file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/deploy_$<CONFIG>.bat"
        CONTENT "$<IF:$<CONFIG:Release>,\"${WINDEPLOYQT}\" \"$<TARGET_FILE:${PROJECT_NAME}>\" --qmldir \"${CMAKE_CURRENT_SOURCE_DIR}/qml\" --no-translations,@echo Deploy skipped (not Release)>"
    )
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND "${CMAKE_BINARY_DIR}/deploy_$<CONFIG>.bat"
        COMMENT "Running windeployqt (Release only)..."
    )
endif()
if (ANDROID)
    set(OPENSSL_PATH_PRIMARY "C:/Users/Antoine/AppData/Local/Android/Sdk/android_openssl/CMakeLists.txt")
    set(OPENSSL_PATH_FALLBACK "C:/AndroidSetup/android_openssl/CMakeLists.txt")

    if(EXISTS "${OPENSSL_PATH_PRIMARY}")
        include(${OPENSSL_PATH_PRIMARY})
    elseif(EXISTS "${OPENSSL_PATH_FALLBACK}")
        include(${OPENSSL_PATH_FALLBACK})
    else()
        message(WARNING "Android OpenSSL CMakeLists.txt not found at either path!")
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
# Target de test P2P dual-instance
# ============================================================================
if(WIN32)
    add_custom_target(dual_test_p2p
        COMMAND cmd /c start "Meownopoly - Instance 1" "$<TARGET_FILE:${PROJECT_NAME}>"
        COMMAND ${CMAKE_COMMAND} -E sleep 2
        COMMAND cmd /c start "Meownopoly - Instance 2" "$<TARGET_FILE:${PROJECT_NAME}>" --instance 2
        DEPENDS ${PROJECT_NAME}
        COMMENT "Lancement du test P2P dual-instance..."
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )
endif()

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
