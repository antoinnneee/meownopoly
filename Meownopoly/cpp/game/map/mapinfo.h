#ifndef MAPINFO_H
#define MAPINFO_H

#include <QString>
#include <QObject>
#include <QList>
#include <QQmlListProperty>

#include "maptypes.h"
#include "playerprofile.h"

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

    Q_PROPERTY(int minPlayers READ minPlayers WRITE setMinPlayers NOTIFY minPlayersChanged FINAL)
    Q_PROPERTY(int maxPlayers READ maxPlayers WRITE setMaxPlayers NOTIFY maxPlayersChanged FINAL)
    Q_PROPERTY(int playerConfigVersion READ playerConfigVersion WRITE setPlayerConfigVersion NOTIFY playerConfigVersionChanged FINAL)
    Q_PROPERTY(QQmlListProperty<PlayerProfile> playerProfiles READ playerProfilesQml NOTIFY playerProfilesChanged FINAL)

public:
    static constexpr int MAX_PLAYERS_HARD_CAP   = 8;
    static constexpr int CURRENT_PLAYER_CONFIG_VERSION = 1;

    MapInfo();
    MapInfo(const QJsonObject &json);
    ~MapInfo();
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

    // ---- Player config ----
    int minPlayers() const { return m_minPlayers; }
    int maxPlayers() const { return m_maxPlayers; }
    int playerConfigVersion() const { return m_playerConfigVersion; }

    void setMinPlayers(int v);
    void setMaxPlayers(int v);
    void setPlayerConfigVersion(int v);

    QList<PlayerProfile *> playerProfiles() const { return m_playerProfiles; }
    QQmlListProperty<PlayerProfile> playerProfilesQml();

    Q_INVOKABLE PlayerProfile* addPlayerProfile();
    Q_INVOKABLE PlayerProfile* addPlayerProfileFromJson(const QString &json);
    Q_INVOKABLE PlayerProfile* duplicatePlayerProfile(const QString &id);
    Q_INVOKABLE void           removePlayerProfile(const QString &id);
    Q_INVOKABLE bool           updatePlayerProfile(const QString &id, const QString &fieldsJson);
    Q_INVOKABLE bool           reorderPlayerProfile(const QString &id, int newIndex);
    Q_INVOKABLE PlayerProfile* playerProfileById(const QString &id) const;
    Q_INVOKABLE int            playerProfileCount() const { return m_playerProfiles.size(); }
    Q_INVOKABLE PlayerProfile* playerProfileAt(int i) const;
    Q_INVOKABLE void           clearPlayerProfiles();

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

    void minPlayersChanged();
    void maxPlayersChanged();
    void playerConfigVersionChanged();
    void playerProfilesChanged();

private:
    // QQmlListProperty static callbacks (read-only)
    static qsizetype profilesCountCb(QQmlListProperty<PlayerProfile> *p);
    static PlayerProfile *profilesAtCb(QQmlListProperty<PlayerProfile> *p, qsizetype i);

    PlayerProfile *adoptProfile(PlayerProfile *p);
    void clearProfilesNoEmit();
    /// Injecte un profil "Princess" par défaut si le roster est vide.
    /// Appelé par les ctors pour garantir qu'une map a toujours au moins un
    /// profil sélectionnable (cf. PLAYER_CONFIG_PANEL_PLAN.md §6.6).
    void ensureFallbackProfile();

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

    int m_minPlayers = 2;
    int m_maxPlayers = MAX_PLAYERS_HARD_CAP;
    int m_playerConfigVersion = CURRENT_PLAYER_CONFIG_VERSION;
    QList<PlayerProfile *> m_playerProfiles;
};

#endif // MAPINFO_H
