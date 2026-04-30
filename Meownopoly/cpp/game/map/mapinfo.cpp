#include "mapinfo.h"
#include <QQmlEngine>
#include <QDebug>

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonValue>
#include <QJsonValueRef>

namespace {

inline int clampInt(int v, int lo, int hi)
{
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

} // namespace

MapInfo::MapInfo()
{
    ensureFallbackProfile();
}

MapInfo::MapInfo(const QJsonObject &json)
{
    m_mapName = json["name"].toString();
    m_mapDescription = json["description"].toString();
    m_mapCreationDate = json["creation"].toString();
    m_mapLastModified = json["lastModified"].toString();
    m_version = json["version"].toInt();

    m_backgroundPath = json["backgroundPath"].toString();
    m_backgroundScaling = json["backgroundScaling"].toString();
    m_backgroundTileSize = json["backgroundTileSize"].toInt(50);
    m_isBackgroundOnGrill = json["isBackgroundOnGrill"].toBool(false);

    m_musicPath = json["musicPath"].toString();

    // ---- Player config ----
    const int loadedVersion = json.value("playerConfigVersion").toInt(0);
    m_minPlayers = clampInt(json.value("minPlayers").toInt(2), 1, MAX_PLAYERS_HARD_CAP);
    m_maxPlayers = clampInt(json.value("maxPlayers").toInt(MAX_PLAYERS_HARD_CAP),
                            qMax(1, m_minPlayers), MAX_PLAYERS_HARD_CAP);

    if (loadedVersion > CURRENT_PLAYER_CONFIG_VERSION) {
        qWarning() << "[MapInfo] playerConfigVersion" << loadedVersion
                   << "is newer than supported" << CURRENT_PLAYER_CONFIG_VERSION
                   << "- resetting roster, fallback profile will be created.";
        m_playerConfigVersion = CURRENT_PLAYER_CONFIG_VERSION;
    } else {
        m_playerConfigVersion = CURRENT_PLAYER_CONFIG_VERSION;
        if (json.contains("playerProfiles") && json.value("playerProfiles").isArray()) {
            const QJsonArray arr = json.value("playerProfiles").toArray();
            for (const QJsonValue &v : arr) {
                if (!v.isObject()) continue;
                adoptProfile(new PlayerProfile(v.toObject(), this));
            }
        }
    }
    // Couvre : version trop récente (roster wipé), JSON sans clé
    // "playerProfiles" (ancienne map pré-Phase 1), ou tableau vide.
    ensureFallbackProfile();
}

MapInfo::~MapInfo()
{
    clearProfilesNoEmit();
}

QString MapInfo::toJSON()
{
    QJsonObject json;
    json["name"] = m_mapName;
    json["description"] = m_mapDescription;
    json["creation"] = m_mapCreationDate;
    json["lastModified"] = m_mapLastModified;
    json["version"] = m_version;

    json["backgroundPath"] = m_backgroundPath;
    json["backgroundScaling"] = m_backgroundScaling;
    json["backgroundTileSize"] = m_backgroundTileSize;
    json["isBackgroundOnGrill"] = m_isBackgroundOnGrill;

    json["musicPath"] = m_musicPath;

    json["minPlayers"] = m_minPlayers;
    json["maxPlayers"] = m_maxPlayers;
    json["playerConfigVersion"] = m_playerConfigVersion;

    QJsonArray profiles;
    for (const PlayerProfile *p : m_playerProfiles) {
        if (p) profiles.append(p->toJSON());
    }
    json["playerProfiles"] = profiles;

    return QJsonDocument(json).toJson(QJsonDocument::Indented);
}

void MapInfo::registerQml()
{
    qmlRegisterType<MapInfo>("MapInfo", 1, 0, "MapInfo");
}

void MapInfo::setMapName(const QString &mapName)
{
    // G2 fix : guard d'égalité avant emit pour éviter les boucles de binding
    // QML (CheckBox/Slider qui re-fire onValueChanged sur ré-évaluation du
    // binding sans changement réel — cf. commit 0e1a16c sur Base_Board).
    if (m_mapName == mapName)
        return;
    m_mapName = mapName;
    emit mapNameChanged(mapName);
}

void MapInfo::setMapDescription(const QString &mapDescription)
{
    if (m_mapDescription == mapDescription)
        return;
    m_mapDescription = mapDescription;
    emit mapDescriptionChanged(mapDescription);
}

void MapInfo::setMapCreationDate(const QString &newMapCreationDate)
{
    if (m_mapCreationDate == newMapCreationDate)
        return;
    m_mapCreationDate = newMapCreationDate;
    emit mapCreationDateChanged();
}

QString MapInfo::getMusicPath() const
{
    return m_musicPath;
}

void MapInfo::setMusicPath(const QString &newMusicPath)
{
    if (m_musicPath == newMusicPath)
        return;
    m_musicPath = newMusicPath;
    emit musicPathChanged();
}

QString MapInfo::getBackgroundPath() const
{
    return m_backgroundPath;
}

void MapInfo::setBackgroundPath(const QString &newBackgroundPath)
{
    if (m_backgroundPath == newBackgroundPath)
        return;
    m_backgroundPath = newBackgroundPath;
    emit backgroundPathChanged();
}

QString MapInfo::getBackgroundScaling() const
{
    return m_backgroundScaling;
}

void MapInfo::setBackgroundScaling(const QString &newBackgroundScaling)
{
    if (m_backgroundScaling == newBackgroundScaling)
        return;
    m_backgroundScaling = newBackgroundScaling;
    emit backgroundScalingChanged();
}

bool MapInfo::getIsBackgroundOnGrill() const
{
    return m_isBackgroundOnGrill;
}

void MapInfo::setIsBackgroundOnGrill(bool newIsBackgroundOnGrill)
{
    if (m_isBackgroundOnGrill == newIsBackgroundOnGrill)
        return;
   m_isBackgroundOnGrill = newIsBackgroundOnGrill;
    emit isBackgroundOnGrillChanged();
}

int MapInfo::getBackgroundTileSize() const
{
    return m_backgroundTileSize;
}

void MapInfo::setBackgroundTileSize(int newBackgroundTileSize)
{
    if (m_backgroundTileSize == newBackgroundTileSize)
        return;
    m_backgroundTileSize = newBackgroundTileSize;
    emit backgroundTileSizeChanged();
}

QString MapInfo::autosaveMapName() const
{
    return m_autosaveMapName;
}


void MapInfo::setMapLastModified(const QString &mapLastModified)
{
    if (m_mapLastModified == mapLastModified)
        return;
    m_mapLastModified = mapLastModified;
    emit mapLastModifiedChanged(mapLastModified);
}

void MapInfo::setVersion(int version)
{
    if (m_version == version)
        return;
    m_version = version;
    emit versionChanged(version);
}

QString MapInfo::getMapName() const
{
    return m_mapName;
}

QString MapInfo::getMapDescription() const
{
    return m_mapDescription;
}

QString MapInfo::getMapLastModified() const
{
    return m_mapLastModified;
}

int MapInfo::getVersion() const
{
    return m_version;
}


QString MapInfo::mapCreationDate() const
{
    return m_mapCreationDate;
}

// ============================================================================
// Player config
// ============================================================================

void MapInfo::setMinPlayers(int v)
{
    const int clamped = clampInt(v, 1, m_maxPlayers);
    if (m_minPlayers == clamped) return;
    m_minPlayers = clamped;
    emit minPlayersChanged();
}

void MapInfo::setMaxPlayers(int v)
{
    const int clamped = clampInt(v, qMax(1, m_minPlayers), MAX_PLAYERS_HARD_CAP);
    if (m_maxPlayers == clamped) return;
    m_maxPlayers = clamped;
    emit maxPlayersChanged();
}

void MapInfo::setPlayerConfigVersion(int v)
{
    if (m_playerConfigVersion == v) return;
    m_playerConfigVersion = v;
    emit playerConfigVersionChanged();
}

qsizetype MapInfo::profilesCountCb(QQmlListProperty<PlayerProfile> *p)
{
    auto *self = qobject_cast<MapInfo *>(p->object);
    return self ? self->m_playerProfiles.size() : 0;
}

PlayerProfile *MapInfo::profilesAtCb(QQmlListProperty<PlayerProfile> *p, qsizetype i)
{
    auto *self = qobject_cast<MapInfo *>(p->object);
    if (!self || i < 0 || i >= self->m_playerProfiles.size()) return nullptr;
    return self->m_playerProfiles.at(i);
}

QQmlListProperty<PlayerProfile> MapInfo::playerProfilesQml()
{
    return QQmlListProperty<PlayerProfile>(this, nullptr,
                                           &MapInfo::profilesCountCb,
                                           &MapInfo::profilesAtCb);
}

PlayerProfile *MapInfo::adoptProfile(PlayerProfile *p)
{
    if (!p) return nullptr;
    p->setParent(this);
    m_playerProfiles.append(p);
    return p;
}

void MapInfo::clearProfilesNoEmit()
{
    qDeleteAll(m_playerProfiles);
    m_playerProfiles.clear();
}

void MapInfo::ensureFallbackProfile()
{
    if (!m_playerProfiles.isEmpty()) return;
    // PlayerProfile() initialise déjà m_name/m_modelName à "Princess"
    // (cf. playerprofile.h). Pas d'émission de signal ici : le ctor MapInfo
    // n'a pas encore de listeners QML attachés. Si appelé hors ctor à l'avenir,
    // l'appelant devra émettre playerProfilesChanged.
    adoptProfile(new PlayerProfile(this));
}

PlayerProfile *MapInfo::addPlayerProfile()
{
    auto *p = adoptProfile(new PlayerProfile(this));
    emit playerProfilesChanged();
    return p;
}

PlayerProfile *MapInfo::addPlayerProfileFromJson(const QString &json)
{
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "[MapInfo] addPlayerProfileFromJson: parse error" << err.errorString();
        return nullptr;
    }
    auto *p = adoptProfile(new PlayerProfile(doc.object(), this));
    emit playerProfilesChanged();
    return p;
}

PlayerProfile *MapInfo::duplicatePlayerProfile(const QString &id)
{
    PlayerProfile *src = playerProfileById(id);
    if (!src) return nullptr;
    QJsonObject j = src->toJSON();
    j.remove("id"); // force nouveau UUID
    auto *p = adoptProfile(new PlayerProfile(j, this));
    emit playerProfilesChanged();
    return p;
}

void MapInfo::removePlayerProfile(const QString &id)
{
    for (int i = 0; i < m_playerProfiles.size(); ++i) {
        PlayerProfile *p = m_playerProfiles.at(i);
        if (p && p->id() == id) {
            m_playerProfiles.removeAt(i);
            p->deleteLater();
            emit playerProfilesChanged();
            return;
        }
    }
}

bool MapInfo::updatePlayerProfile(const QString &id, const QString &fieldsJson)
{
    PlayerProfile *p = playerProfileById(id);
    if (!p) return false;
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(fieldsJson.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "[MapInfo] updatePlayerProfile: parse error" << err.errorString();
        return false;
    }
    p->applyJson(doc.object());
    return true;
}

bool MapInfo::reorderPlayerProfile(const QString &id, int newIndex)
{
    int oldIndex = -1;
    for (int i = 0; i < m_playerProfiles.size(); ++i) {
        if (m_playerProfiles.at(i) && m_playerProfiles.at(i)->id() == id) {
            oldIndex = i;
            break;
        }
    }
    if (oldIndex < 0) return false;
    const int clamped = clampInt(newIndex, 0, m_playerProfiles.size() - 1);
    if (clamped == oldIndex) return true;
    m_playerProfiles.move(oldIndex, clamped);
    emit playerProfilesChanged();
    return true;
}

PlayerProfile *MapInfo::playerProfileById(const QString &id) const
{
    for (PlayerProfile *p : m_playerProfiles) {
        if (p && p->id() == id) return p;
    }
    return nullptr;
}

PlayerProfile *MapInfo::playerProfileAt(int i) const
{
    if (i < 0 || i >= m_playerProfiles.size()) return nullptr;
    return m_playerProfiles.at(i);
}

void MapInfo::clearPlayerProfiles()
{
    if (m_playerProfiles.isEmpty()) return;
    for (PlayerProfile *p : m_playerProfiles) {
        if (p) p->deleteLater();
    }
    m_playerProfiles.clear();
    emit playerProfilesChanged();
}
