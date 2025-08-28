#ifndef MAP_H
#define MAP_H

#include <QObject>
#include "item_snapable/ItemSnapable.h"

class Map : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString mapName READ mapName WRITE setMapName NOTIFY mapNameChanged FINAL)
    Q_PROPERTY(QString mapVersion READ mapVersion WRITE setMapVersion NOTIFY mapVersionChanged FINAL)
    Q_PROPERTY(QString mapDescription READ mapDescription WRITE setMapDescription NOTIFY mapDescriptionChanged FINAL)
    Q_PROPERTY(QList<ItemSnapable*> caseTiles READ caseTiles NOTIFY caseTilesChanged FINAL)
    Q_PROPERTY(QList<ItemSnapable*> decorationTiles READ decorationTiles NOTIFY decorationTilesChanged FINAL)

public:
    Map(QObject *parent = nullptr);
    void extracted(Case *&caseData, QJsonArray &nextIdArray);
    Map(QJsonObject jsonObject, QObject *parent = nullptr);

    QString mapName() const { return m_mapName; }
    void setMapName(const QString &mapName) { m_mapName = mapName; emit mapNameChanged(); }
    QString mapVersion() const { return m_mapVersion; }
    void setMapVersion(const QString &mapVersion) { m_mapVersion = mapVersion; emit mapVersionChanged(); }
    QString mapDescription() const { return m_mapDescription; }
    void setMapDescription(const QString &mapDescription) { m_mapDescription = mapDescription; emit mapDescriptionChanged(); }


    QList<ItemSnapable*> caseTiles() const { return m_caseTiles; }
    void setCaseTiles(const QList<ItemSnapable*> &caseTiles) { m_caseTiles = caseTiles; emit caseTilesChanged(); }


    QList<ItemSnapable*> decorationTiles() const { return m_decorationTiles; }
    void setDecorationTiles(const QList<ItemSnapable*> &decorationTiles) { m_decorationTiles = decorationTiles; emit decorationTilesChanged(); }

signals:
    void mapNameChanged();
    void mapVersionChanged();
    void mapDescriptionChanged();
    
    void caseTilesChanged();
    void decorationTilesChanged();

private:
    QString m_mapName;
    QString m_mapVersion;
    QString m_mapDescription;
    QList<ItemSnapable*> m_caseTiles;
    QList<ItemSnapable*> m_decorationTiles;

};

#endif // MAP_H
