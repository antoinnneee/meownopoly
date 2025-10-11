#include <QCoreApplication>
#include <QVariantMap>
#include <QVariantList>
#include <QList>
#include <QDebug>
#include "game.h"
#include "case/CaseRestArea.h"
#include "case/CaseKibbleDispenser.h"
#include "case/CaseCardBoardBox.h"
#include "case/CaseCatNip.h"
#include "case/CaseJail.h"
#include "case/CaseToJail.h"
#include "case/CaseCatDoor.h"
#include "case/CaseFreeNap.h"
#include "case/CaseCatDevice.h"

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    
    // Créer une instance du jeu
    Game *game = Game::instance();
    
    // Informations de la map
    QVariantMap mapInfo;
    mapInfo["name"] = "Meownopoly Classic";
    mapInfo["version"] = "1.0";
    mapInfo["description"] = "Map classique du jeu Meownopoly";
    
    // Créer des cases pour la map
    QList<Case*> caseInfo;
    QList<QVariantMap> caseDisplayInfo;
    
    // Case de départ (Kibble Dispenser)
    CaseKibbleDispenser *startCase = new CaseKibbleDispenser("Départ", QUuid::createUuid(), 200, game);
    caseInfo.append(startCase);
    
    QVariantMap startDisplay;
    startDisplay["unitSizeWidth"] = 2;
    startDisplay["unitSizeHeight"] = 2;
    startDisplay["gridRelativePositionX"] = 0;
    startDisplay["gridRelativePositionY"] = 0;
    startDisplay["zLayer"] = 0;
    caseDisplayInfo.append(startDisplay);
    
    // Case RestArea (propriété)
    QList<int> rentPrices;
    rentPrices << 50 << 100 << 200 << 300 << 400 << 500;
    CaseRestArea *restArea1 = new CaseRestArea("Zone de Repos 1", QUuid::createUuid(), 100, 200, 200, game, 
                                               CaseRestArea::FamilyType::FAMILY_1, 50, 100, rentPrices);
    caseInfo.append(restArea1);
    
    QVariantMap restArea1Display;
    restArea1Display["unitSizeWidth"] = 1;
    restArea1Display["unitSizeHeight"] = 1;
    restArea1Display["gridRelativePositionX"] = 2;
    restArea1Display["gridRelativePositionY"] = 0;
    restArea1Display["zLayer"] = 0;
    caseDisplayInfo.append(restArea1Display);
    
    // Case CardBoardBox (Caisse de Communauté)
    CaseCardBoardBox *cardBox = new CaseCardBoardBox("Caisse de Communauté", QUuid::createUuid(), game);
    caseInfo.append(cardBox);
    
    QVariantMap cardBoxDisplay;
    cardBoxDisplay["unitSizeWidth"] = 1;
    cardBoxDisplay["unitSizeHeight"] = 1;
    cardBoxDisplay["gridRelativePositionX"] = 3;
    cardBoxDisplay["gridRelativePositionY"] = 0;
    cardBoxDisplay["zLayer"] = 0;
    caseDisplayInfo.append(cardBoxDisplay);
    
    // Case CatNip (Chance)
    CaseCatNip *catNip = new CaseCatNip("Chance", QUuid::createUuid(), game);
    caseInfo.append(catNip);
    
    QVariantMap catNipDisplay;
    catNipDisplay["unitSizeWidth"] = 1;
    catNipDisplay["unitSizeHeight"] = 1;
    catNipDisplay["gridRelativePositionX"] = 4;
    catNipDisplay["gridRelativePositionY"] = 0;
    catNipDisplay["zLayer"] = 0;
    caseDisplayInfo.append(catNipDisplay);
    
    // Case CatDoor (Gare)
    CaseCatDoor *catDoor = new CaseCatDoor("Gare Centrale", QUuid::createUuid(), 100, 200, 200, game);
    caseInfo.append(catDoor);
    
    QVariantMap catDoorDisplay;
    catDoorDisplay["unitSizeWidth"] = 1;
    catDoorDisplay["unitSizeHeight"] = 1;
    catDoorDisplay["gridRelativePositionX"] = 5;
    catDoorDisplay["gridRelativePositionY"] = 0;
    catDoorDisplay["zLayer"] = 0;
    caseDisplayInfo.append(catDoorDisplay);
    
    // Case Jail (Prison)
    CaseJail *jail = new CaseJail("Prison", QUuid::createUuid(), 50);
    caseInfo.append(jail);
    
    QVariantMap jailDisplay;
    jailDisplay["unitSizeWidth"] = 1;
    jailDisplay["unitSizeHeight"] = 1;
    jailDisplay["gridRelativePositionX"] = 6;
    jailDisplay["gridRelativePositionY"] = 0;
    jailDisplay["zLayer"] = 0;
    caseDisplayInfo.append(jailDisplay);
    
    // Case ToJail (Allez en Prison)
    CaseToJail *toJail = new CaseToJail("Allez en Prison", QUuid::createUuid(), game);
    caseInfo.append(toJail);
    
    QVariantMap toJailDisplay;
    toJailDisplay["unitSizeWidth"] = 1;
    toJailDisplay["unitSizeHeight"] = 1;
    toJailDisplay["gridRelativePositionX"] = 7;
    toJailDisplay["gridRelativePositionY"] = 0;
    toJailDisplay["zLayer"] = 0;
    caseDisplayInfo.append(toJailDisplay);
    
    // Case FreeNap (Parc Gratuit)
    CaseFreeNap *freeNap = new CaseFreeNap("Parc Gratuit", QUuid::createUuid(), game);
    caseInfo.append(freeNap);
    
    QVariantMap freeNapDisplay;
    freeNapDisplay["unitSizeWidth"] = 1;
    freeNapDisplay["unitSizeHeight"] = 1;
    freeNapDisplay["gridRelativePositionX"] = 8;
    freeNapDisplay["gridRelativePositionY"] = 0;
    freeNapDisplay["zLayer"] = 0;
    caseDisplayInfo.append(freeNapDisplay);
    
    // Case CatDevice (Compagnie)
    CaseCatDevice *catDevice = new CaseCatDevice("Compagnie d'Électricité", QUuid::createUuid(), 75, 150, 150, game, 0);
    caseInfo.append(catDevice);
    
    QVariantMap catDeviceDisplay;
    catDeviceDisplay["unitSizeWidth"] = 1;
    catDeviceDisplay["unitSizeHeight"] = 1;
    catDeviceDisplay["gridRelativePositionX"] = 9;
    catDeviceDisplay["gridRelativePositionY"] = 0;
    catDeviceDisplay["zLayer"] = 0;
    caseDisplayInfo.append(catDeviceDisplay);
    
    // Informations de décoration (optionnel)
    QVariantMap decoInfo;
    decoInfo["theme"] = "cat";
    decoInfo["background"] = "grass";
    decoInfo["ambient"] = "day";
    
    // Sauvegarder la map
    bool success = game->saveMap(mapInfo, caseInfo, caseDisplayInfo, decoInfo);
    
    if (success) {
        qDebug() << "Map générée avec succès!";
    } else {
        qDebug() << "Erreur lors de la génération de la map.";
    }
    
    // Nettoyer la mémoire
    for (Case* casePtr : caseInfo) {
        delete casePtr;
    }
    
    return 0;
}
