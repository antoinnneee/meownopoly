#include "game.h"

#include "case/caserestarea.h"
#include <QQmlApplicationEngine>
#include <QQmlEngine>

#include <QFile>
#include <QString>

#define CASE_TYPE_COLUMN 0
#define CASE_NAME_COLUMN 1
#define CASE_RESTQUALITY_COLUMN 2
#define CASE_PRICE_COLUMN 3
#define CASE_PRICE_COUNT 6

void Game::init_caseFile()
{
    QFile caseFile(CASE_FILE_PATH);

    if (!caseFile.open(QIODevice::ReadOnly)) {
        qDebug()<< "Cases file not found";
    }

    QList<QByteArray> caseInfo = caseFile.readAll().split('\n');
    qDebug() << caseInfo;
    int line = 1;   // skip first line
    while (line <  caseInfo.count())
    {
        QList<QByteArray> caseInfoLine = caseInfo.at(line).split(',');
        line++;
        QString typeStr = caseInfoLine[CASE_TYPE_COLUMN];
        int type = typeStr.toInt();
        switch (type)
        {
            case CT_RestArea:
            {
                int i = 0;
                QVector<int> prices;
                while (i < CASE_PRICE_COUNT)
                {
                    prices.append(caseInfoLine[CASE_PRICE_COLUMN + i].toInt());
                    i++;
                }
//                enum RestQuality rq =  (enum RestQuality) caseInfoLine[CASE_RESTQUALITY_COLUMN].toInt();
                CaseRestArea* boardCase = new CaseRestArea(caseInfoLine[CASE_NAME_COLUMN],
                               prices);
                m_board.append(boardCase);
                CaseRestArea* bc = (CaseRestArea*)m_board.last();
               bc ->print_state();
                break;
            }
            default :
                qDebug() << "type unknow" << caseInfoLine;
                break;
        }
    }

}

void Game::init()
{
    init_caseFile();

}
