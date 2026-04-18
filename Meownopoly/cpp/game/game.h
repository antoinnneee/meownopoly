#ifndef GAME_H
#define GAME_H

#include <QObject>
#include <QQmlEngine>
#include <QVector>
#include <QList>
#include <QVariant>
#include <QDir>
#include <QJsonArray>
#include <QJsonObject>
#include <QUuid>
#include "game/case/Case.h"
#include "game/case/CaseRestArea.h"

#include "card.h"
#include "game/player.h"
#include "game/item_snapable/ItemSnapable.h"
#include "map/mapinfo.h"
#include "map/map.h"
#include "map/maptypes.h"
#include "map/editdelta.h"


class Game : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int boardSize READ boardSize CONSTANT)
    Q_PROPERTY(int currentPlayerIndex READ currentPlayerIndex NOTIFY currentPlayerIndexChanged)

    Q_PROPERTY(QList<Player*> players READ players NOTIFY playersChanged)
    Q_PROPERTY(QList<Player *> listPlayers READ listPlayers CONSTANT FINAL)
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

    Q_INVOKABLE void startGame();
    Q_INVOKABLE void checkSaveSettings();

    Q_INVOKABLE Player *createPlayer(const QString name, QColor color, int indexLogo, int kibbles);
    Q_INVOKABLE void setupPlayers(const QVariantList &playerData);

    Q_INVOKABLE void nextPlayer();
    Q_INVOKABLE Player *getPlayer();
    
    // Case library functions for UI
    Q_INVOKABLE QList<Case*> getPurchasableCases() const;

    QList<Player*> players() const { return m_listPlayers; }
    int boardSize() const { return 40; }
    int currentPlayerIndex() const;

    Q_INVOKABLE Case* getNewCaseType(Case::CaseType type);
    Q_INVOKABLE Player* getNewPlayer();


    QList<Player *> listPlayers() const;

    Case **listCases() const;

    QList<Card *> listCards() const;

    // Map saving/loading
    DisplayParameter *getDisplayerParameter(const QVariantMap &displayInfoMap);
    QJsonArray formatTileDataToJson(ItemSnapable &is, QJsonArray snapableTilesArray);

    Q_INVOKABLE bool saveCurrentMap();
    Q_INVOKABLE bool saveMap(MapInfo* mapInfo, QVariantList itemSnapableList, MapTypes::MapType mapType);
    Q_INVOKABLE bool deleteMap(QString mapName, MapTypes::MapType mapType);
    Q_INVOKABLE Map *loadMap(QString mapName, MapTypes::MapType mapType);

    Q_INVOKABLE QList<ItemSnapable*> generateItems(QJsonObject jsonObject);

    Q_INVOKABLE void askPreview();
    Q_INVOKABLE void askNext();

    // ---- Delta undo/redo + save orchestration ----
    static bool saveOnEdit();
    // Orchestre : mutation de m_tiles + push delta + commit shadow + save
    // (différée si en transaction). Remplace l'ancien updateEditState.
    Q_INVOKABLE void updateMap(int type, ItemSnapable* tile, QUuid groupId = {});
    // Idem pour les métadonnées. Remplace updateEditMetadata.
    Q_INVOKABLE void updateMapMetadata(const QString& beforeJson, const QString& afterJson);
    Q_INVOKABLE QUuid beginTransaction();
    Q_INVOKABLE void  commitTransaction();
    // Libère le C++ ItemSnapable stashé par map->removeTile (appelé par QML
    // à la fin de l'animation de suppression).
    Q_INVOKABLE void  finalizeDeletedTile(const QUuid &tileId);

    // Template saving/loading
    Q_INVOKABLE bool saveTemplate(QString name, QJsonArray elementsJson);
    Q_INVOKABLE bool deleteTemplate(QString name);
    Q_INVOKABLE QJsonObject loadTemplate(QString name);
    Q_INVOKABLE QJsonArray getTemplateElementsForPlacement(QString name, int targetX, int targetY);


    ~Game();

signals:
    void gameStarted();

    void clearCurrentMap();

    void playersChanged();
    void currentPlayerIndexChanged();
    void propertyPurchased(int position, Player* newOwner);

    void mapLoaded(Map *map);
    void foundItemSnapableTile(ItemSnapable *itemSnapable);

    // Delta undo/redo signals relayed to QML
    void tileRemoved(QUuid tileId);
    void forceUnselectAll();
    // Relayé depuis Map::afterRestoration
    void afterRestoration(const QList<QUuid> &tileIds);


private:
    explicit Game(QObject *parent = nullptr);
    static Game *m_pThis;
    QList<Case*> m_board;
    QList<Player*> m_listPlayers;
    Player* m_players;
    QList<Card*>  m_listCards;
    QList<CaseRestArea*>    m_family[CaseRestArea::FT_COUNT];

    int m_currentPlayerIndex = 0;

    QUuid m_currentTransaction;
    bool  m_txDirty = false;
};

#endif // GAME_H
