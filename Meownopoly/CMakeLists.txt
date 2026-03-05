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

# ============================================================================
# Chemins d'import QML (pour Qt Creator et le code model)
# ============================================================================
set(QML_IMPORT_PATH 
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/qml
    ${CMAKE_CURRENT_SOURCE_DIR}/qml/editor/panel/bottomPanel/bottomSidePanel/
    CACHE STRING "QML Import Path" FORCE
)

# ============================================================================
# Configuration de déploiement
# ============================================================================
# Windows : configuration pour windeployqt (optionnel, décommentez si besoin)
# if(WIN32)
#     set(DEPLOY_SCRIPT "${CMAKE_CURRENT_BINARY_DIR}/deploy.bat")
#     file(WRITE ${DEPLOY_SCRIPT} 
#         "windeployqt \"$<TARGET_FILE:${PROJECT_NAME}>\" --qmldir \"${CMAKE_CURRENT_SOURCE_DIR}/qml\" --no-translations"
#     )
#     add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
#         COMMAND ${DEPLOY_SCRIPT}
#         COMMENT "Running windeployqt..."
#     )
# endif()

# Linux/Unix
if(UNIX AND NOT ANDROID AND NOT APPLE)
    install(TARGETS ${PROJECT_NAME}
        RUNTIME DESTINATION /opt/${PROJECT_NAME}/bin
    )
endif()

# QNX
if(QNX)
    install(TARGETS ${PROJECT_NAME}
        RUNTIME DESTINATION /tmp/${PROJECT_NAME}/bin
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
