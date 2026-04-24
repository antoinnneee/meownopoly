#ifndef MAPINFO_H
#define MAPINFO_H

#include <QString>
#include <QObject>

#include "maptypes.h"

#define AUTOSAVE_MAP_NAME "autosave_tmp"


class MapInfo : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString mapName READ getMapName WRITE setMapName NOTIFY mapNameChanged)
    Q_PROPERTY(QString mapDescription READ getMapDescription WRITE setMapDescription NOTIFY mapDescriptionChanged)
    Q_PROPERTY(QString mapCreationDate READ mapCreationDate WRITE setMapCreationDate NOTIFY mapCreationDateChanged)
    Q_PROPERTY(QString mapLastModified READ getMapLastModified WRITE setMapLastModified NOTIFY mapLastModifiedChanged)
    Q_PROPERTY(int version READ getVersion WRITE setVersion NOTIFY versionChanged)

    Q_PROPERTY(QString musicPath READ getMusicPath WRITE setMusicPath NOTIFY musicPathChanged FINAL)
    Q_PROPERTY(QString backgroundPath READ getBackgroundPath WRITE setBackgroundPath NOTIFY backgroundPathChanged FINAL)
    Q_PROPERTY(QString backgroundScaling READ getBackgroundScaling WRITE setBackgroundScaling NOTIFY backgroundScalingChanged FINAL)
    Q_PROPERTY(bool isBackgroundOnGrill READ getIsBackgroundOnGrill WRITE setIsBackgroundOnGrill NOTIFY isBackgroundOnGrillChanged FINAL)
    Q_PROPERTY(int backgroundTileSize READ getBackgroundTileSize WRITE setBackgroundTileSize NOTIFY backgroundTileSizeChanged FINAL)
    Q_PROPERTY(QString autosaveMapName READ autosaveMapName CONSTANT FINAL)

public:


    MapInfo();
    MapInfo(const QJsonObject &json);
    static void registerQml();

    Q_INVOKABLE QString toJSON();

    
    void setMapName(const QString &mapName);
    void setMapDescription(const QString &mapDescription);
    void setMapLastModified(const QString &mapLastModified);
    void setVersion(int version);

    QString getMapName() const;
    QString getMapDescription() const;
    QString getMapLastModified() const;
    int getVersion() const;


    QString mapCreationDate() const;
    void setMapCreationDate(const QString &newMapCreationDate);

    QString getMusicPath() const;
    void setMusicPath(const QString &newMusicPath);

    QString getBackgroundPath() const;
    void setBackgroundPath(const QString &newBackgroundPath);

    QString getBackgroundScaling() const;
    void setBackgroundScaling(const QString &newBackgroundScaling);

    bool getIsBackgroundOnGrill() const;
    void setIsBackgroundOnGrill(bool newIsBackgroundOnGrill);

    int getBackgroundTileSize() const;
    void setBackgroundTileSize(int newBackgroundTileSize);


    QString autosaveMapName() const;

signals:
    void mapNameChanged(const QString &mapName);
    void mapDescriptionChanged(const QString &mapDescription);
    void mapLastModifiedChanged(const QString &mapLastModified);
    void versionChanged(int version);

    void mapCreationDateChanged();

    void musicPathChanged();

    void backgroundPathChanged();

    void backgroundScalingChanged();

    void isBackgroundOnGrillChanged();

    void backgroundTileSizeChanged();


private:

    const QString m_autosaveMapName = AUTOSAVE_MAP_NAME;
    QString m_mapName = m_autosaveMapName;

    QString m_mapDescription = "";
    QString m_mapCreationDate = "";
    QString m_mapLastModified = "";
    int m_version = 0;

    QString m_backgroundPath = "";
    QString m_backgroundScaling = "Fit";
    int m_backgroundTileSize = 200;
    bool m_isBackgroundOnGrill = false;

    QString m_musicPath = "";
};

#endif // MAPINFO_H
