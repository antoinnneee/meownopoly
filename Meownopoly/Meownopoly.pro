QT += quick core qml widgets core-private quickcontrols2

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

CONFIG += c++20

# You can make your code fail to compile if it uses deprecated APIs.
# In order to do so, uncomment the following line.
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000    # disables all the APIs deprecated before Qt 6.0.0

SOURCES += \
    case/Case.cpp \
    case/CaseCatDevice.cpp \
    case/CaseCatDoor.cpp \
    case/CaseCatNip.cpp \
    case/CaseCardBoardBox.cpp \
    case/CaseCatPerks.cpp \
    case/CaseFreeNap.cpp \
    case/CaseJail.cpp \
    case/CaseKibbleDispenser.cpp \
    case/CaseToJail.cpp \
    case/caserestarea.cpp \
    case/casestart.cpp \
    game.cpp \
    game_loader.cpp \
    main.cpp \
    player.cpp \
    qmlapp.cpp \
    tools/appinfo.cpp \

HEADERS += \
    case/Case.h \
    case/CaseCatDevice.h \
    case/CaseCatDoor.h \
    case/CaseCatNip.h \
    case/CaseCardBoardBox.h \
    case/CaseCatPerks.h \
    case/CaseFreeNap.h \
    case/CaseJail.h \
    case/CaseKibbleDispenser.h \
    case/CaseToJail.h \
    case/caserestarea.h \
    case/casestart.h \
    game.h \
    player.h \
    qmlapp.h \
    tools/debug_Info.h	\
    tools/appinfo.h \

RESOURCES += qml.qrc \
    asset.qrc \
    config.qrc

# Additional import path used to resolve QML modules in Qt Creator's code model
QML_IMPORT_PATH =

# Additional import path used to resolve QML modules just for Qt Quick Designer
QML_DESIGNER_IMPORT_PATH =

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

