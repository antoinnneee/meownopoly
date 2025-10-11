#ifndef MAP_H
#define MAP_H

#include <QObject>
#include "MapInfo.h"
#include "item_snapable/ItemSnapable.h"

class Map : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QList<ItemSnapable*> caseTiles READ caseTiles NOTIFY caseTilesChanged FINAL)
    Q_PROPERTY(QList<ItemSnapable*> decorationTiles READ decorationTiles NOTIFY decorationTilesChanged FINAL)

    Q_PROPERTY(MapInfo *mapInfo READ getMapInfo WRITE setMapInfo NOTIFY mapInfoChanged FINAL)

public:
    Map(QObject *parent = nullptr);
    Map(QJsonObject jsonObject, QObject *parent = nullptr);

    QList<ItemSnapable*> caseTiles() const { return m_caseTiles; }
    void setCaseTiles(const QList<ItemSnapable*> &caseTiles) { m_caseTiles = caseTiles; emit caseTilesChanged(); }


    QList<ItemSnapable*> decorationTiles() const { return m_decorationTiles; }
    void setDecorationTiles(const QList<ItemSnapable*> &decorationTiles) { m_decorationTiles = decorationTiles; emit decorationTilesChanged(); }

    MapInfo *getMapInfo() const;
    void setMapInfo(MapInfo *newMapInfo);

signals:
    void caseTilesChanged();
    void decorationTilesChanged();

    void mapInfoChanged();

private:

    QList<ItemSnapable*> m_caseTiles;
    QList<ItemSnapable*> m_decorationTiles;

    MapInfo *mapInfo = nullptr;

};

#endif // MAP_H
