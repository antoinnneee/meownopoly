#ifndef GAME_H
#define GAME_H

#include <QObject>
#include <QQmlEngine>
#include <QVector>
#include <QList>
#include <QVariant>
#include <QDir>
#include "case/Case.h"
#include "case/CaseCatPerks.h"
#include "case/CaseRestArea.h"

#include "card.h"
#include "player.h"
#include "item_snapable/ItemSnapable.h"

#define CASE_FILE_PATH ":/config/cases.json"

class Game : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int boardSize READ boardSize CONSTANT)
    Q_PROPERTY(int currentPlayerIndex READ currentPlayerIndex NOTIFY currentPlayerIndexChanged)

    Q_PROPERTY(QList<Player*> players READ players NOTIFY playersChanged)
    Q_PROPERTY(QList<Player *> listPlayers READ listPlayers CONSTANT FINAL)
    Q_PROPERTY(QList<Card *> listCards READ listCards CONSTANT FINAL)

    Q_PROPERTY(int assetNumber READ assetNumber WRITE setAssetNumber NOTIFY assetNumberChanged FINAL)
    Q_PROPERTY(QVariantList assetPath READ assetPath WRITE setAssetPath NOTIFY assetPathChanged FINAL)

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

    Q_INVOKABLE Player *createPlayer(const QString name, QColor color, int indexLogo, int kibbles);
    Q_INVOKABLE void setupPlayers(const QVariantList &playerData);

    Q_INVOKABLE void nextPlayer();
    Q_INVOKABLE Player *getPlayer();


    QList<Player*> players() const { return m_listPlayers; }
    int boardSize() const { return 40; }  // Standard Monopoly board size
    int currentPlayerIndex() const;

    Q_INVOKABLE Case* getNewCaseType(Case::CaseType type);
    Q_INVOKABLE Player* getNewPlayer();


    QList<Player *> listPlayers() const;

    Case **listCases() const;

    QList<Card *> listCards() const;

    // JSON Case Management

    DisplayParameter *getDisplayerParameter(const QVariantMap &displayInfoMap);
    QJsonArray formatTileDataToJson(ItemSnapable &is, QJsonArray snapableTilesArray);
    bool addTileToJson(QJsonObject jsonObject, QString mapName);
    Q_INVOKABLE bool registerMap(QVariantMap mapInfo, QVariantList  caseList, QVariantList  decorationList);
    // Q_INVOKABLE bool saveMap(const QMap<QString,QVariant> &mapInfo, QList<Case *> caseInfo, QList<QVariantMap> caseDisplayInfo, const QVariantMap &decoInfo);



    Q_INVOKABLE bool saveCaseToJson(const QVariantMap &caseData);
    Q_INVOKABLE bool saveMultipleCasesToJson(const QVariantList &casesData);




    ~Game();

    int assetNumber() const;
    void setAssetNumber(int newAssetNumber);

    QVariantList assetPath() const;
    Q_INVOKABLE QVariant getAssetPath(int index) const;

    void setAssetPath(const QVariantList &newAssetPath);

public slots:

signals:
    void gameStarted();

    void playersChanged();
    void currentPlayerIndexChanged();
    void propertyPurchased(int position, Player* newOwner);

    void assetNumberChanged();
    void assetPathChanged();

private slots:

private:
    explicit Game(QObject *parent = nullptr);
    static Game *m_pThis;
    QList<Case*> m_board;
    QList<Player*> m_listPlayers;
    Player* m_players;
    // QList<Case*> m_listCases;
    QList<Card*>  m_listCards;
    QList<CaseRestArea*>    m_family[CaseRestArea::FT_COUNT];

    int userSelectNext = 0;
    int userSelectPrev = 0;

    int m_currentPlayerIndex = 0;

    int m_assetNumber = 0;

    QVariantList m_assetPath;
};

#endif // GAME_H
