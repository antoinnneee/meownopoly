#ifndef GAME_H
#define GAME_H

#include <QObject>
#include <QQmlEngine>
#include <QVector>
#include <QList>
#include <QVariant>
#include "case/Case.h"
#include "case/CaseCatPerks.h"
#include "case/CaseRestArea.h"
#include "card.h"
#include "player.h"

#define CASE_FILE_PATH ":/config/cases.json"

class Game : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int boardSize READ boardSize CONSTANT)
    Q_PROPERTY(int currentPlayerIndex READ currentPlayerIndex NOTIFY currentPlayerIndexChanged)

    Q_PROPERTY(QList<Player*> players READ players NOTIFY playersChanged)
    Q_PROPERTY(QList<Player *> listPlayers READ listPlayers CONSTANT FINAL)
    Q_PROPERTY(QList<Case *> listCases READ listCases CONSTANT FINAL)
    Q_PROPERTY(QList<Card *> listCards READ listCards CONSTANT FINAL)

public:

    enum GAME_CONDITION {
        ABANDON,
        BANKRUPT,
        CTN_TURN
    };

    static void registerQml();
    static Game *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    Q_INVOKABLE void init();    // create a new game, load caseFile
    Q_INVOKABLE void startGame();
    void initCases();
    Case *getNewCase(const QStringList&);
    void initCards();

    Q_INVOKABLE Player *createPlayer(const QString name, QColor color, int indexLogo, int kibbles);
    Q_INVOKABLE void setupPlayers(const QVariantList &playerData);

    Q_INVOKABLE void nextPlayer();
    Q_INVOKABLE Player *getPlayer();
    Q_INVOKABLE Case* getCaseAt(int position);


    QList<Player*> players() const { return m_listPlayers; }
    int boardSize() const { return 40; }  // Standard Monopoly board size
    int currentPlayerIndex() const;

    Q_INVOKABLE Case* getNewCaseType(Case::CaseType type);


    QList<Player *> listPlayers() const;

    QList<Case *> listCases() const;

    QList<Card *> listCards() const;

public slots:

signals:
    void gameStarted();

    void playersChanged();
    void currentPlayerIndexChanged();
    void propertyPurchased(int position, Player* newOwner);

private slots:

private:
    explicit Game(QObject *parent = nullptr);
    ~Game(){};
    static Game *m_pThis;
    QList<Case*> m_board;
    QList<Player*> m_listPlayers;
    Player* m_players;
    QList<Case*> m_listCases;
    QList<Card*>  m_listCards;
    QList<CaseRestArea*>    m_family[FT_COUNT];
    //    QList<card_chance*> commu;
    //    QList<card_chance*>chance;
    int m_currentPlayerIndex = 0;

    void init_caseFile();
};

#endif // GAME_H
