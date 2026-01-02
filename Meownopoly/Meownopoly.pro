QT += quick core qml widgets core-private quickcontrols2 network quick3d sql websockets

android:{
    QT += core-private

    ANDROID_VERSION_CODE = 1
    ANDROID_VERSION_NAME = 1-indev
    DEFINES+= APP_VERSION_CODE='\"$${ANDROID_VERSION_CODE}\"'
    DEFINES+= APP_VERSION_NAME='\"$${ANDROID_VERSION_NAME}\"'

    appinfo.obj.depends = FORCE
    QMAKE_EXTRA_TARGETS += appinfo.obj
    PRE_TARGETDEPS += appinfo.obj
}

#if changement in path need to REBUILD !
DEFINES += BUILD_DIR=\\\"$$OUT_PWD\\\"

# windows: {
#     DESTDIR = $$PWD/bin/windows/release
#     QMAKE_POST_LINK =  windeployqt $$shell_path($$DESTDIR/$${TARGET}.exe) --qmldir $$PWD/qml --no-translations
# }

CONFIG += c++20

# You can make your code fail to compile if it uses deprecated APIs.
# In order to do so, uncomment the following line.
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000    # disables all the APIs deprecated before Qt 6.0.0

# Ajouter cpp au chemin de recherche pour les sources et headers
VPATH += cpp
# Ajouter cpp au chemin d'inclusion pour que les includes puissent omettre cpp/
INCLUDEPATH += cpp

SOURCES += \
    cpp/game/item_snapable/ZoneParameter.cpp \
    cpp/game/physics/collision2d.cpp \
    cpp/game/physics/pattounx_body.cpp \
    cpp/game/physics/pattounx_zone.cpp \
    cpp/game/physics/pattounx_engine.cpp \
    tools/QtFolderCompressor/FolderCompressor.cpp \
    assetManager/asset_manager.cpp \
    game/case/Case.cpp \
    game/case/CaseCatDevice.cpp \
    game/case/CaseCatDoor.cpp \
    game/case/CaseCatNip.cpp \
    game/case/CaseCardBoardBox.cpp \
    game/case/CaseCatPerks.cpp \
    game/case/CaseFactory.cpp \
    game/case/CaseFreeNap.cpp \
    game/case/CaseJail.cpp \
    game/case/CaseKibbleDispenser.cpp \
    game/case/CaseRestArea.cpp \
    game/case/CaseToJail.cpp \
    game/card.cpp \
    game/game.cpp \
    game/game_loader.cpp \
    game/player.cpp \
    experiment/animation_manager.cpp \
    experiment/animationprovider.cpp \
    experiment/liveimage.cpp \
    game/item_snapable/Displayparameter.cpp \
    game/item_snapable/ItemSnapable.cpp \
    game/item_snapable/decorationparameter.cpp \
    game/item_snapable/itemsnapablefactory.cpp \
    launcher/launcher_manager.cpp \
    main.cpp \
    game/map/map.cpp \
    game/map/mapinfo.cpp \
    game/map/mapfilemanager.cpp \
    game/meowstyle.cpp \
    qmlapp.cpp \
    tools/appinfo.cpp \
    tools/cursor_manager.cpp \
    tools/editorenum.cpp \
    tools/logger.cpp \
    game/map/undoredomanager.cpp \
    chat/chat_client.cpp \
    chat/chat_crypto.cpp \
    chat/chat_database.cpp \
    chat/chat_worker.cpp \


HEADERS += \
    cpp/game/item_snapable/ZoneParameter.h \
    cpp/game/physics/collision2d.h \
    cpp/game/physics/pattounx_body.h \
    cpp/game/physics/pattounx_zone.h \
    cpp/game/physics/pattounx_engine.h \
    tools/QtFolderCompressor/FolderCompressor.h \
    assetManager/asset_manager.h \
    game/case/Case.h \
    game/case/CaseCatDevice.h \
    game/case/CaseCatDoor.h \
    game/case/CaseCatNip.h \
    game/case/CaseCardBoardBox.h \
    game/case/CaseCatPerks.h \
    game/case/CaseFactory.h \
    game/case/CaseFreeNap.h \
    game/case/CaseJail.h \
    game/case/CaseKibbleDispenser.h \
    game/case/CaseRestArea.h \
    game/case/CaseToJail.h \
    cpp/game/card.h \
    cpp/game/game.h \
    cpp/game/player.h \
    experiment/animation_manager.h \
    experiment/animationprovider.h \
    experiment/liveimage.h \
    game/item_snapable/Displayparameter.h \
    game/item_snapable/ItemSnapable.h \
    game/item_snapable/decorationparameter.h \
    game/item_snapable/itemsnapablefactory.h \
    launcher/launcher_manager.h \
    game/map/map.h \
    game/map/mapinfo.h \
    game/map/mapfilemanager.h \
    game/map/maptypes.h \
    game/meowstyle.h \
    qmlapp.h \
    tools/debug_Info.h	\
    tools/appinfo.h \
    tools/cursor_manager.h \
    tools/editorenum.h \
    tools/logger.h \
    game/map/undoredomanager.h \
    chat/chat_client.h \
    chat/chat_crypto.h \
    chat/chat_database.h \
    chat/chat_worker.h \

RESOURCES += qml.qrc

# CONFIG += qmlcache  # Désactivé car nécessite TARGETPATH pour Qt 6.10+

# Additional import path used to resolve QML modules in Qt Creator's code model
QML_IMPORT_PATH = $$PWD
QML_IMPORT_PATH += $$PWD/qml

# Additional import path used to resolve QML modules just for Qt Quick Designer
QML_DESIGNER_IMPORT_PATH = $$PWD/case/

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

DISTFILES += \


