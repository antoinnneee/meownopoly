#ifndef MAPINFO_H
#define MAPINFO_H

#include <QString>
#include <QObject>

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


public:
    MapInfo();
    MapInfo(const QJsonObject &json);
    static void registerQml();

    QString toJSON();

    
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

signals:
    void mapNameChanged(const QString &mapName);
    void mapDescriptionChanged(const QString &mapDescription);
    void mapLastModifiedChanged(const QString &mapLastModified);
    void versionChanged(int version);

    void mapCreationDateChanged();

    void musicPathChanged();

    void backgroundPathChanged();

    void backgroundScalingChanged();

private:
    QString m_mapName = "no_name";
    QString m_mapDescription = "no_description";
    QString m_mapCreationDate = "no_creation";
    QString m_mapLastModified = "no_last_modified";
    int m_version = 0;

    QString musicPath = "";

    QString backgroundPath = "";
    QString backgroundScaling = "Stretch";
};

#endif // MAPINFO_H
