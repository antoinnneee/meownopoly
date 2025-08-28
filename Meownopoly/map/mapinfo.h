#ifndef MAPINFO_H
#define MAPINFO_H

#include <QString>
#include <QObject>

class MapInfo : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString mapName READ getMapName WRITE setMapName NOTIFY mapNameChanged)
    Q_PROPERTY(QString mapDescription READ getMapDescription WRITE setMapDescription NOTIFY mapDescriptionChanged)
    Q_PROPERTY(QString mapLastModified READ getMapLastModified WRITE setMapLastModified NOTIFY mapLastModifiedChanged)
    Q_PROPERTY(int version READ getVersion WRITE setVersion NOTIFY versionChanged)


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


signals:
    void mapNameChanged(const QString &mapName);
    void mapDescriptionChanged(const QString &mapDescription);
    void mapLastModifiedChanged(const QString &mapLastModified);
    void versionChanged(int version);

private:
    QString m_mapName = "no_name";
    QString m_mapDescription = "no_description";
    QString m_mapLastModified = "no_last_modified";
    int m_version = 0;

};

#endif // MAPINFO_H
