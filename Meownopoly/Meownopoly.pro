QT += quick core qml widgets core-private quickcontrols2 network

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
    QtFolderCompressor/FolderCompressor.cpp \
    assetManager/asset_manager.cpp \
    case/Case.cpp \
    case/CaseCatDevice.cpp \
    case/CaseCatDoor.cpp \
    case/CaseCatNip.cpp \
    case/CaseCardBoardBox.cpp \
    case/CaseCatPerks.cpp \
    case/CaseFactory.cpp \
    case/CaseFreeNap.cpp \
    case/CaseJail.cpp \
    case/CaseKibbleDispenser.cpp \
    case/CaseRestArea.cpp \
    case/CaseToJail.cpp \
    cpp/game/card.cpp \
    cpp/game/game.cpp \
    cpp/game/game_loader.cpp \
    cpp/game/player.cpp \
    experiment/animation_manager.cpp \
    experiment/animationprovider.cpp \
    experiment/liveimage.cpp \
    item_snapable/Displayparameter.cpp \
    item_snapable/ItemSnapable.cpp \
    item_snapable/decorationparameter.cpp \
    item_snapable/itemsnapablefactory.cpp \
    launcher/launcher_manager.cpp \
    main.cpp \
    map/map.cpp \
    map/mapinfo.cpp \
    map/mapfilemanager.cpp \
    meowstyle.cpp \
    qmlapp.cpp \
    tools/appinfo.cpp \
    tools/cursor_manager.cpp \
    tools/editorenum.cpp \
    tools/logger.cpp \
    tools/undoredomanager.cpp \


HEADERS += \
    QtFolderCompressor/FolderCompressor.h \
    assetManager/asset_manager.h \
    case/Case.h \
    case/CaseCatDevice.h \
    case/CaseCatDoor.h \
    case/CaseCatNip.h \
    case/CaseCardBoardBox.h \
    case/CaseCatPerks.h \
    case/CaseFactory.h \
    case/CaseFreeNap.h \
    case/CaseJail.h \
    case/CaseKibbleDispenser.h \
    case/CaseRestArea.h \
    case/CaseToJail.h \
    cpp/game/card.h \
    cpp/game/game.h \
    cpp/game/player.h \
    experiment/animation_manager.h \
    experiment/animationprovider.h \
    experiment/liveimage.h \
    item_snapable/Displayparameter.h \
    item_snapable/ItemSnapable.h \
    item_snapable/decorationparameter.h \
    item_snapable/itemsnapablefactory.h \
    launcher/launcher_manager.h \
    map/map.h \
    map/mapinfo.h \
    map/mapfilemanager.h \
    map/maptypes.h \
    meowstyle.h \
    qmlapp.h \
    tools/debug_Info.h	\
    tools/appinfo.h \
    tools/cursor_manager.h \
    tools/editorenum.h \
    tools/logger.h \
    tools/undoredomanager.h \

RESOURCES += qml.qrc

# CONFIG += qmlcache  # Désactivé car nécessite TARGETPATH pour Qt 6.10+

# Additional import path used to resolve QML modules in Qt Creator's code model
QML_IMPORT_PATH = $$PWD

# Additional import path used to resolve QML modules just for Qt Quick Designer
QML_DESIGNER_IMPORT_PATH = $$PWD/case/

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

DISTFILES += \


