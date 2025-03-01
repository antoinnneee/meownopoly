#include "game.h"
#include <QDebug>

#include "case/caserestarea.h"
#include "case/CaseKibbleDispenser.h"
#include "case/CaseCardBoardBox.h"
#include "case/CaseCatNip.h"
#include "case/CaseJail.h"
#include "case/CaseToJail.h"
#include "case/CaseCatDoor.h"
#include "case/CaseFreeNap.h"
#include <QQmlApplicationEngine>
#include <QQmlEngine>

#include <QFile>
#include <QString>

#define CASE_TYPE_COLUMN 0
#define CASE_NAME_COLUMN 1
#define CASE_FAMILY_COLUMN 2
#define CASE_PRICE_COLUMN 3
#define CASE_PRICE_COUNT 6
#define CASE_HOME_PRICE_COLUMN 9
#define CASE_HOTEL_PRICE_COLUMN 10

void Game::init_caseFile()
{
    QFile caseFile(CASE_FILE_PATH);

    if (!caseFile.open(QIODevice::ReadOnly)) {
        qDebug() << "Cases file not found";
        return;
    }

    QList<QByteArray> caseInfo = caseFile.readAll().split('\n');
    qDebug() << "Loading " << caseInfo.count() << " cases from file";
    
    int line = 1;   // skip first line (header)
    int position = 0; // track position on board
    
    // Create a jail case pointer to reference later
    CaseJail* jailCase = nullptr;
    
    while (line < caseInfo.count())
    {
        QList<QByteArray> caseInfoLine = caseInfo.at(line).split(',');
        line++;
        
        // Skip empty lines
        if (caseInfoLine.isEmpty() || caseInfoLine[0].isEmpty()) {
            continue;
        }
        
        QString typeStr = caseInfoLine[CASE_TYPE_COLUMN];
        int type = typeStr.toInt();
        QString name = caseInfoLine[CASE_NAME_COLUMN];
        
        Case* boardCase = nullptr;
        
        switch (type)
        {
            case CT_KibbleDispenser: // Start
            {
                int reward = 200; // Default reward for passing start
                CaseKibbleDispenser* kibbleCase = new CaseKibbleDispenser(name, position, reward, this);
                boardCase = kibbleCase;
                qDebug() << "Created Kibble Dispenser at position" << position;
                break;
            }
            case CT_RestArea: // Properties
            {
                QVector<int> prices;
                for (int i = 0; i < CASE_PRICE_COUNT; i++) {
                    if (CASE_PRICE_COLUMN + i < caseInfoLine.size() && !caseInfoLine[CASE_PRICE_COLUMN + i].isEmpty()) {
                        prices.append(caseInfoLine[CASE_PRICE_COLUMN + i].toInt());
                    } else {
                        prices.append(0);
                    }
                }
                
                FamilyType family = FT_NONE;
                if (CASE_FAMILY_COLUMN < caseInfoLine.size() && !caseInfoLine[CASE_FAMILY_COLUMN].isEmpty()) {
                    family = static_cast<FamilyType>(caseInfoLine[CASE_FAMILY_COLUMN].toInt());
                }
                
                CaseRestArea* restCase = new CaseRestArea(name, prices, family, position, this);
                boardCase = restCase;
                qDebug() << "Created Rest Area at position" << position << "with family" << family;
                break;
            }
            case CT_CardBoardBox: // Community Chest
            {
                CaseCardBoardBox* cardBoardCase = new CaseCardBoardBox(name, position);
                boardCase = cardBoardCase;
                qDebug() << "Created Card Board Box at position" << position;
                break;
            }
            case CT_CatNip: // Chance
            {
                CaseCatNip* catNipCase = new CaseCatNip(name, position);
                boardCase = catNipCase;
                qDebug() << "Created Cat Nip at position" << position;
                break;
            }
            case CT_Jail: // Jail
            {
                int jailFine = 50; // Default jail fine
                CaseJail* jailCaseNew = new CaseJail(name, position, jailFine);
                jailCase = jailCaseNew; // Save reference to jail case
                boardCase = jailCaseNew;
                qDebug() << "Created Jail at position" << position;
                break;
            }
            case CT_ToJail: // Go to Jail
            {
                CaseToJail* toJailCase = new CaseToJail(name, position, this);
                boardCase = toJailCase;
                qDebug() << "Created Go To Jail at position" << position;
                break;
            }
            case CT_CatDoor: // Railroad
            {
                int baseRent = 25;
                if (CASE_PRICE_COLUMN < caseInfoLine.size() && !caseInfoLine[CASE_PRICE_COLUMN].isEmpty()) {
                    baseRent = caseInfoLine[CASE_PRICE_COLUMN].toInt();
                }
                
                CaseCatDoor* catDoorCase = new CaseCatDoor(name, position, baseRent);
                boardCase = catDoorCase;
                qDebug() << "Created Cat Door at position" << position << "with rent" << baseRent;
                break;
            }
            case CT_FreeNap: // Free Parking
            {
                CaseFreeNap* freeNapCase = new CaseFreeNap(name, position, this);
                boardCase = freeNapCase;
                qDebug() << "Created Free Nap at position" << position;
                break;
            }
            case CT_WaterFountain: // Utility 1
            case CT_LaserPointer: // Utility 2
            {
                // For now, treat utilities as regular properties
                int baseRent = 0;
                if (CASE_PRICE_COLUMN < caseInfoLine.size() && !caseInfoLine[CASE_PRICE_COLUMN].isEmpty()) {
                    baseRent = caseInfoLine[CASE_PRICE_COLUMN].toInt();
                }
                
                CaseCatDoor* utilityCase = new CaseCatDoor(name, position, baseRent);
                boardCase = utilityCase;
                qDebug() << "Created Utility at position" << position << "with rent" << baseRent;
                break;
            }
            case CT_GoldenCollar: // Luxury Tax
            case CT_FurTax: // Income Tax
            {
                int taxAmount = 0;
                if (CASE_PRICE_COLUMN < caseInfoLine.size() && !caseInfoLine[CASE_PRICE_COLUMN].isEmpty()) {
                    taxAmount = caseInfoLine[CASE_PRICE_COLUMN].toInt();
                }
                
                // For now, treat taxes as kibble dispensers with negative rewards
                CaseKibbleDispenser* taxCase = new CaseKibbleDispenser(name, position, -taxAmount, this);
                boardCase = taxCase;
                qDebug() << "Created Tax at position" << position << "with amount" << taxAmount;
                break;
            }
            default:
                qDebug() << "Unknown case type" << type << "at position" << position;
                break;
        }
        
        if (boardCase) {
            m_board.append(boardCase);
            position++;
        }
    }
    
    // Connect ToJail cases to the Jail case
    if (jailCase) {
        for (Case* boardCase : m_board) {
            if (boardCase->getType() == CT_ToJail) {
                CaseToJail* toJailCase = qobject_cast<CaseToJail*>(boardCase);
                if (toJailCase) {
                    toJailCase->setJailCase(jailCase);
                }
            }
        }
    }
    
    qDebug() << "Loaded" << m_board.size() << "cases";
}

void Game::init()
{
    init_caseFile();
}
