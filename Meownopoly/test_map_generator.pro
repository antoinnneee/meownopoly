QT += core
QT -= gui

CONFIG += c++17 console
CONFIG -= app_bundle

TEMPLATE = app

# Inclure les fichiers du projet principal
INCLUDEPATH += .

# Fichiers sources
SOURCES += \
    test_map_generator.cpp \
    game.cpp \
    player.cpp \
    card.cpp \
    Decoration.cpp \
    case/Case.cpp \
    case/CaseRestArea.cpp \
    case/CaseCardBoardBox.cpp \
    case/CaseCatNip.cpp \
    case/CaseJail.cpp \
    case/CaseToJail.cpp \
    case/CaseCatDoor.cpp \
    case/CaseFreeNap.cpp \
    case/CaseCatDevice.cpp \
    case/CaseKibbleDispenser.cpp \
    case/CaseCatPerks.cpp \
    item_snapable/ItemSnapable.cpp \
    item_snapable/SnapableCase.cpp \
    item_snapable/SnapableDeco.cpp

# Fichiers d'en-tête
HEADERS += \
    game.h \
    player.h \
    card.h \
    Decoration.h \
    case/Case.h \
    case/CaseRestArea.h \
    case/CaseCardBoardBox.h \
    case/CaseCatNip.h \
    case/CaseJail.h \
    case/CaseToJail.h \
    case/CaseCatDoor.h \
    case/CaseFreeNap.h \
    case/CaseCatDevice.h \
    case/CaseKibbleDispenser.h \
    case/CaseCatPerks.h \
    item_snapable/ItemSnapable.h \
    item_snapable/SnapableCase.h \
    item_snapable/SnapableDeco.h

# Définitions
DEFINES += QT_DEPRECATED_WARNINGS

# Nom de l'exécutable
TARGET = test_map_generator
