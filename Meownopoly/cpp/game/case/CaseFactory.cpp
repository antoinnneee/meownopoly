#include "CaseFactory.h"
#include "CaseRestArea.h"
#include "CaseCardBoardBox.h"
#include "CaseCatNip.h"
#include "CaseJail.h"
#include "CaseToJail.h"
#include "CaseCatDoor.h"
#include "CaseFreeNap.h"
#include "CaseCatDevice.h"
#include "CaseKibbleDispenser.h"

CaseFactory::CaseFactory() {}

void CaseFactory::registerCaseQml()
{
    // // Register the complete inheritance hierarchy for proper QML inheritance
    qmlRegisterUncreatableType<Case>("Case", 1, 0, "Case",
                                     "Case is an abstract base class"); // Register Case class with enum
    qmlRegisterUncreatableType<CaseCatPerks>("CaseCatPerks", 1, 0, "CaseCatPerks",
                                             "CaseCatPerks is an intermediate base class"); // Register intermediate class
    qmlRegisterType<CaseRestArea>("CaseRestArea", 1, 0,
                                  "CaseRestArea"); // Register CaseRestArea class
    qmlRegisterType<CaseKibbleDispenser>("CaseKibbleDispenser", 1, 0,
                                         "CaseKibbleDispenser"); // Register CaseKibbleDispenser class
    qmlRegisterType<CaseCardBoardBox>("CaseCardBoardBox", 1, 0,
                                      "CaseCardBoardBox"); // Register CaseCardBoardBox class
    qmlRegisterType<CaseCatNip>("CaseCatNip", 1, 0,
                                "CaseCatNip"); // Register CaseCatNip class
    qmlRegisterType<CaseJail>("CaseJail", 1, 0,
                              "CaseJail"); // Register CaseJail class
    qmlRegisterType<CaseToJail>("CaseToJail", 1, 0,
                                "CaseToJail"); // Register CaseToJail class
    qmlRegisterType<CaseCatDoor>("CaseCatDoor", 1, 0,
                                 "CaseCatDoor"); // Register CaseCatDoor class
    qmlRegisterType<CaseFreeNap>("CaseFreeNap", 1, 0,
                                 "CaseFreeNap"); // Register CaseFreeNap class
    qmlRegisterType<CaseCatDevice>("CaseCatDevice", 1, 0,
                                   "CaseCatDevice"); // Register CaseCatDevice class
}

Case *CaseFactory::createCase(CaseType type)
{
    Case* newCase = nullptr;

    switch (type) {
    case Case::CS_RestArea:
    {
        newCase = new CaseRestArea("test restArea");
        QList<int> rentList;
        rentList.append(50);
        rentList.append(100);
        rentList.append(200);
        rentList.append(300);
        rentList.append(400);
        rentList.append(5000);
        ((CaseRestArea*)newCase)->setRentPrice(rentList);
        break;
    }
    case Case::CS_KibbleDispenser:
        newCase = new CaseKibbleDispenser("test KibbleDispenser", 200);
        break;
    case Case::CS_CardBoardBox:
        newCase = new CaseCardBoardBox("test CardBoardBox");
        break;
    case Case::CS_CatNip:
        newCase = new CaseCatNip("test CatNip");
        break;
    case Case::CS_Jail:
        newCase = new CaseJail("test Jail");
        break;
    case Case::CS_ToJail:
        newCase = new CaseToJail("test ToJail");
        break;
    case Case::CS_CatDoor:
        newCase = new CaseCatDoor("test CatDoor");
        break;
    case Case::CS_FreeNap:
        newCase = new CaseFreeNap("test FreeNap");
        break;
    case Case::CS_Device:
        newCase = new CaseCatDevice("test CatDevice");
        break;
    case Case::CS_Taxe:
        newCase = new CaseKibbleDispenser("TAXE NOT IMPLEMENTED");
        break;
    default:
        //qDebug() << "Unknown case type:" << type << "returning NULL";
        break;
    }
    return newCase;
}

Case* CaseFactory::createCase(const QJsonObject &caseJson)
{
    Case* newCase = nullptr;
    
    // Extract type from JSON and convert to enum
    Case::CaseType type = Case::intToCaseType(caseJson["type"].toInt());
    switch (type) {
    case Case::CS_RestArea:
        newCase = new CaseRestArea(caseJson);
        break;
    case Case::CS_KibbleDispenser:
        newCase = new CaseKibbleDispenser(caseJson); // Default kibble amount
        break;
    case Case::CS_CardBoardBox:
        newCase = new CaseCardBoardBox(caseJson);
        break;
    case Case::CS_CatNip:
        newCase = new CaseCatNip(caseJson);
        break;
    case Case::CS_Jail:
        newCase = new CaseJail(caseJson);
        break;
    case Case::CS_ToJail:
        newCase = new CaseToJail(caseJson);
        break;
    case Case::CS_CatDoor:
        newCase = new CaseCatDoor(caseJson);
        break;
    case Case::CS_FreeNap:
        newCase = new CaseFreeNap(caseJson);
        break;
    case Case::CS_Device:
        newCase = new CaseCatDevice(caseJson);
        break;
    case Case::CS_Taxe:
        newCase = new CaseKibbleDispenser(caseJson); // Tax case as KibbleDispenser
        break;
    default:
        // qDebug() << "Unknown case type:" << type << "creating base Case";
        newCase = new Case(caseJson);
        break;
    }

    return newCase;
}

