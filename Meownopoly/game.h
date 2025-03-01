#ifndef GAME_H
#define GAME_H

#include <QObject>
#include <QQmlEngine>
#include "case/Case.h"
#include "player.h"
#define CASE_FILE_PATH ":/config/cases.csv"

class Game : public QObject
{
    Q_OBJECT

public:
    static void registerQml();
    static Game *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    Q_INVOKABLE void debugButton();
    Q_INVOKABLE void init();    // create a new game, load caseFile 
    Q_INVOKABLE void createPlayer(const QString &name);

    int boardSize() const;
    Case* getCaseAt(int position);

public slots:

signals:

private slots:

private:
    explicit Game(QObject *parent = nullptr);
    static Game *m_pThis;
    QList<Case*> m_board;
    QList<Player*> m_players;
    
    void init_caseFile();
};

#endif // GAME_H
