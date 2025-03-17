#ifndef GAME_H
#define GAME_H

#include <QObject>
#include <QQmlEngine>
#include <QVector>
#include "case/Case.h"
#include "player.h"

#define CASE_FILE_PATH ":/config/cases.csv"

class Game : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QList<Player*> players READ players NOTIFY playersChanged)
    Q_PROPERTY(int boardSize READ boardSize CONSTANT)
    Q_PROPERTY(int currentPlayerIndex READ currentPlayerIndex NOTIFY currentPlayerIndexChanged)

public:
    static void registerQml();
    static Game *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    Q_INVOKABLE void debugButton();
    Q_INVOKABLE void init();    // create a new game, load caseFile
    Q_INVOKABLE void createPlayer(const QString &name);
    Q_INVOKABLE void setupPlayers(const QVariantList &playerData);

    Q_INVOKABLE Case* getCaseAt(int position);
    QList<Player*> players() const { return m_players; }

    Q_INVOKABLE void startGame();
    Q_INVOKABLE void movePlayer(int playerIndex, int steps);
    Q_INVOKABLE void nextPlayer();
    
    int boardSize() const { return 40; }  // Standard Monopoly board size
    int currentPlayerIndex() const;

public slots:

signals:
    void gameStarted();
    void playersChanged();
    void currentPlayerIndexChanged();

private slots:

private:
    explicit Game(QObject *parent = nullptr);
    ~Game(){};
    static Game *m_pThis;
    QList<Case*> m_board;
    QList<Player*> m_players;
    int m_currentPlayerIndex = 0;

    void init_caseFile();
};

#endif // GAME_H
