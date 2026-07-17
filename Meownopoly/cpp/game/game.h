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
#include <QTimer>

#include "game/item_snapable/ItemSnapable.h"
#include "map/mapinfo.h"
#include "map/map.h"
#include "map/maptypes.h"
#include "map/editdelta.h"


class Game : public QObject
{
    Q_OBJECT

    // Valeur que Game::tickLamport() retournerait au prochain appel, sans
    // incrémenter. Utilisé par les previews (AssetPreviewCursor, etc.) pour
    // se rendre à la z-height exacte qu'aura la tile après pose.
    Q_PROPERTY(double previewZOrder READ previewZOrder NOTIFY lamportClockChanged FINAL)

public:

    static void registerQml();
    static Game *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    Q_INVOKABLE void startGame();

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

    // Applique un EditDelta reçu d'un peer (Pattern B). Ne pushe PAS le delta
    // sur la pile undo locale (chacun son gestionnaire). Le flag
    // beginApplyRemote/endApplyRemote est déjà actif dans le signal réception.
    Q_INVOKABLE void applyRemoteDelta(int type, const QString &tileId, const QString &groupId,
                                      const QJsonObject &before, const QJsonObject &after,
                                      bool applyBefore);

    // Crée une Map vide, la connecte et la définit comme current. Utilisé par
    // le client collaboratif qui rejoint une session : il n'a pas de fichier
    // local à loadMap, mais a besoin d'un Map pour que updateMap/applyRemoteDelta
    // puissent muter m_tiles.
    Q_INVOKABLE void initEmptyCollabMap();

    // Template saving/loading
    Q_INVOKABLE bool saveTemplate(QString name, QJsonArray elementsJson);
    Q_INVOKABLE bool deleteTemplate(QString name);
    Q_INVOKABLE QJsonObject loadTemplate(QString name);
    Q_INVOKABLE QJsonArray getTemplateElementsForPlacement(QString name, int targetX, int targetY);

    // ---- Lamport clock pour zOrder des tiles ----
    // Un compteur logique monotone commun à toutes les créations de tile.
    // En local : tickLamport() fournit un zOrder monotone (plus de float drift).
    // En collab : chaque peer fait tickLamport() localement, broadcast avec la
    // tuile (le zOrder transporte la valeur). À réception, syncLamport() garde
    // le compteur local ≥ au maximum vu. Les ties concurrents (deux peers qui
    // tickent avant échange) sont cassés au rendu par (playerId, uniqueId) :
    // c'est à l'appelant du sort de l'intégrer si nécessaire.
    Q_INVOKABLE double tickLamport();
    Q_INVOKABLE void   syncLamport(double remote);
    Q_INVOKABLE void   resetLamport();
    // Lecture seule du compteur logique (SANS tick). Consommé par le
    // GameplayEventBus (V3 piste D) comme horloge externe : le bus garantit
    // sa propre monotonie et ne doit pas faire churner les zOrder/previews.
    qint64 lamportClock() const { return m_lamportClock; }
    double previewZOrder() const;
    // Scanne une Map et sync le compteur au max des zOrder trouvés. Appelé
    // après loadMap pour qu'une nouvelle création ne collisionne pas avec
    // l'historique du fichier.
    void syncLamportFromMap(Map *map);


    ~Game();

signals:
    void gameStarted();

    void clearCurrentMap();

    void mapLoaded(Map *map);
    void foundItemSnapableTile(ItemSnapable *itemSnapable);

    // Delta undo/redo signals relayed to QML
    void tileRemoved(QUuid tileId);
    void forceUnselectAll();
    // Relayé depuis Map::afterRestoration
    void afterRestoration(const QList<QUuid> &tileIds);

    // Émis à chaque mutation de m_lamportClock (tick/sync/reset). Alimente
    // la Q_PROPERTY previewZOrder pour que les previews suivent.
    void lamportClockChanged();


private:
    explicit Game(QObject *parent = nullptr);
    static Game *m_pThis;

    QUuid m_currentTransaction;
    bool  m_txDirty = false;

    // Phase 4 — coalesce les saveCurrentMap déclenchés par applyRemoteDelta
    // (ex. FullSync → N TileAdded d'affilée). start() restartable ; émet un
    // seul write ~500 ms après la dernière op distante.
    QTimer *m_remoteSaveDebounce = nullptr;

    // Lamport clock — int64 monotone, partie entière du zOrder assigné.
    // La partie fractionnaire (m_lamportJitter) est fixe par session et
    // désambigue les ticks concurrents entre peers lors du rendu.
    qint64 m_lamportClock  = 0;
    double m_lamportJitter = 0.0;
};

#endif // GAME_H
