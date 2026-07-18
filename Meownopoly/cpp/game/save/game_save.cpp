#include "save/game_save.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QLockFile>
#include <QUuid>
#include <QDebug>

#include "memory/memory_store.h"
#include "modules/gameplay_module_manager.h"

// ============================================================================
// GameSaveMapRef
// ============================================================================

QJsonObject GameSaveMapRef::toJson() const
{
    QJsonObject o;
    o.insert(QStringLiteral("id"), id);
    o.insert(QStringLiteral("version"), version);
    o.insert(QStringLiteral("hash"), hash);
    return o;
}

GameSaveMapRef GameSaveMapRef::fromJson(const QJsonObject &obj)
{
    GameSaveMapRef ref;
    ref.id      = obj.value(QStringLiteral("id")).toString();
    ref.version = obj.value(QStringLiteral("version")).toInt();
    ref.hash    = obj.value(QStringLiteral("hash")).toString();
    return ref;
}

// ============================================================================
// GameSave — construction / QML
// ============================================================================

GameSave::GameSave(QObject *parent)
    : QObject(parent)
{
    m_saveId    = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_createdAt = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
}

void GameSave::registerQml()
{
    // Type instanciable côté QML (pas un singleton : plusieurs sauvegardes
    // peuvent coexister — liste, chargement, aperçu). Le câblage effectif dans
    // qmlapp.cpp est différé à l'intégration du chargement en jeu (T4-3/T4-5) ;
    // exposer le type ici garde la brique auto-suffisante et testable.
    qmlRegisterType<GameSave>("MeowSave", 1, 0, "GameSave");
}

void GameSave::setSaveName(const QString &name)
{
    if (m_saveName == name)
        return;
    m_saveName = name;
    emit changed();
}

// ============================================================================
// Sérialisation
// ============================================================================

QJsonObject GameSave::toJson() const
{
    QJsonObject root;
    root.insert(QStringLiteral("saveVersion"), CURRENT_SAVE_VERSION);
    root.insert(QStringLiteral("saveId"), m_saveId);
    root.insert(QStringLiteral("saveName"), m_saveName);
    root.insert(QStringLiteral("createdAt"), m_createdAt);
    root.insert(QStringLiteral("lastSavedAt"),
                QDateTime::currentDateTimeUtc().toString(Qt::ISODate));

    root.insert(QStringLiteral("map"), m_mapRef.toJson());
    root.insert(QStringLiteral("rulebook"), m_rulebook);
    // Secrets retirés du blob mémoire avant écriture (D20).
    root.insert(QStringLiteral("memory"), sanitizeSecrets(m_memory));
    root.insert(QStringLiteral("players"), m_players);
    root.insert(QStringLiteral("modules"), m_modules);
    root.insert(QStringLiteral("artifacts"), m_artifacts);
    root.insert(QStringLiteral("clocks"), m_clocks);
    return root;
}

bool GameSave::loadJson(const QJsonObject &obj)
{
    const int version = obj.value(QStringLiteral("saveVersion")).toInt(-1);
    if (version < 0) {
        qWarning() << "[GameSave] loadJson : champ 'saveVersion' absent — sauvegarde rejetée";
        return false;
    }
    if (version > CURRENT_SAVE_VERSION) {
        qWarning() << "[GameSave] loadJson : saveVersion" << version
                   << "> version comprise" << CURRENT_SAVE_VERSION << "— refus";
        return false;
    }

    m_saveId      = obj.value(QStringLiteral("saveId")).toString(m_saveId);
    m_saveName    = obj.value(QStringLiteral("saveName")).toString();
    m_createdAt   = obj.value(QStringLiteral("createdAt")).toString();
    m_lastSavedAt = obj.value(QStringLiteral("lastSavedAt")).toString();

    m_mapRef    = GameSaveMapRef::fromJson(obj.value(QStringLiteral("map")).toObject());
    m_rulebook  = obj.value(QStringLiteral("rulebook")).toObject();
    m_memory    = obj.value(QStringLiteral("memory")).toObject();
    m_players   = obj.value(QStringLiteral("players")).toArray();
    m_modules   = obj.value(QStringLiteral("modules")).toObject();
    m_artifacts = obj.value(QStringLiteral("artifacts")).toArray();
    m_clocks    = obj.value(QStringLiteral("clocks")).toObject();

    emit changed();
    return true;
}

QVariantMap GameSave::toVariantMap() const
{
    return toJson().toVariantMap();
}

bool GameSave::loadVariantMap(const QVariantMap &map)
{
    return loadJson(QJsonObject::fromVariantMap(map));
}

// ============================================================================
// Assemblage de commodité
// ============================================================================

void GameSave::captureRuntimeState()
{
    // Mémoire (session + joueurs) et état des modules sont portés par des
    // singletons globaux → captés ici. Joueurs, artefacts, horloges et
    // référence map dépendent du contexte de partie (pas d'un singleton) et
    // restent renseignés explicitement par l'appelant.
    m_memory  = MemoryStore::instance()->toJson();
    m_modules = GameplayModuleManager::instance()->moduleStateJson();
    emit changed();
}

// ============================================================================
// I/O fichier (atomique — patron MapFileManager::saveMap)
// ============================================================================

bool GameSave::saveToFile(const QString &saveName) const
{
    return writeSave(toJson(), saveName);
}

bool GameSave::loadFromFile(const QString &saveName)
{
    const QJsonObject obj = readSave(saveName);
    if (obj.isEmpty())
        return false;
    return loadJson(obj);
}

QStringList GameSave::availableSaveNames() const
{
    return availableSaves();
}

QString GameSave::saveFilePathFor(const QString &saveName) const
{
    return saveFilePath(saveName);
}

bool GameSave::writeSave(const QJsonObject &data, const QString &saveName)
{
    const QString filePath = saveFilePath(saveName);

    // Le dossier de sauvegardes existe ?
    QDir dir = QFileInfo(filePath).dir();
    if (!dir.exists() && !dir.mkpath(QStringLiteral("."))) {
        qWarning() << "[GameSave] Impossible de créer le dossier de sauvegarde :" << dir.path();
        return false;
    }

    // Verrou pour éviter les écritures concurrentes (même contrat que les maps).
    QLockFile lockFile(filePath + QStringLiteral(".lock"));
    if (!lockFile.tryLock(3000)) {
        qWarning() << "[GameSave] Verrou d'écriture indisponible :" << filePath;
        return false;
    }

    // Écriture atomique : fichier temporaire puis rename.
    const QString tmpFilePath = filePath + QStringLiteral(".tmp");
    QFile tmpFile(tmpFilePath);
    if (!tmpFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "[GameSave] Ouverture du fichier temporaire impossible :" << tmpFilePath;
        return false;
    }

    const QByteArray jsonData = QJsonDocument(data).toJson(QJsonDocument::Indented);
    const qint64 bytesWritten = tmpFile.write(jsonData);
    tmpFile.close();

    if (bytesWritten == -1) {
        qWarning() << "[GameSave] Écriture du fichier temporaire échouée :" << tmpFilePath;
        QFile::remove(tmpFilePath);
        return false;
    }

    if (QFile::exists(filePath))
        QFile::remove(filePath);
    if (!QFile::rename(tmpFilePath, filePath)) {
        qWarning() << "[GameSave] Rename du fichier temporaire échoué vers :" << filePath;
        QFile::remove(tmpFilePath);
        return false;
    }

    return true;
}

QJsonObject GameSave::readSave(const QString &saveName)
{
    const QString filePath = saveFilePath(saveName);

    QLockFile lockFile(filePath + QStringLiteral(".lock"));
    if (!lockFile.tryLock(3000)) {
        qWarning() << "[GameSave] Verrou de lecture indisponible :" << filePath;
        return QJsonObject();
    }

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        qDebug() << "[GameSave] Ouverture en lecture impossible :" << filePath;
        return QJsonObject();
    }

    const QByteArray data = file.readAll();
    file.close();

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "[GameSave] JSON invalide dans" << filePath << ":" << parseError.errorString();
        return QJsonObject();
    }

    return doc.object();
}

bool GameSave::removeSave(const QString &saveName)
{
    const QString filePath = saveFilePath(saveName);
    if (!QFile::exists(filePath))
        return false;
    return QFile::remove(filePath);
}

bool GameSave::saveExists(const QString &saveName)
{
    return QFile::exists(saveFilePath(saveName));
}

QStringList GameSave::availableSaves()
{
    QStringList saves;
    QDir saveDir(GAME_SAVE_PATH);
    if (!saveDir.exists())
        return saves;

    const QString suffix = QStringLiteral(GAME_SAVE_SUFFIX);
    const QFileInfoList files =
        saveDir.entryInfoList(QStringList{ QStringLiteral("*") + suffix }, QDir::Files);
    for (const QFileInfo &fi : files) {
        QString name = fi.fileName();
        if (name.endsWith(suffix))
            name.chop(suffix.length());
        saves.append(name);
    }
    return saves;
}

QString GameSave::saveFilePath(const QString &saveName)
{
    return QString(GAME_SAVE_PATH) + normalizeSaveName(saveName) + QStringLiteral(GAME_SAVE_SUFFIX);
}

// ============================================================================
// Hash + référence map + assainissement
// ============================================================================

QString GameSave::computeContentHash(const QJsonObject &obj)
{
    // JSON compact : QJsonDocument trie les clés → forme canonique déterministe,
    // condition d'un hash comparable de bout en bout (même contrat que
    // V3Envelope::computePayloadHash).
    const QByteArray compact = QJsonDocument(obj).toJson(QJsonDocument::Compact);
    const QByteArray digest  = QCryptographicHash::hash(compact, QCryptographicHash::Sha256);
    return QStringLiteral("sha256:") + QString::fromLatin1(digest.toHex());
}

GameSaveMapRef GameSave::buildMapRef(const QString &mapId, int version,
                                     const QJsonObject &mapJson)
{
    GameSaveMapRef ref;
    ref.id      = mapId;
    ref.version = version;
    ref.hash    = mapJson.isEmpty() ? QString() : computeContentHash(mapJson);
    return ref;
}

QJsonObject GameSave::sanitizeSecrets(const QJsonObject &memory)
{
    // Clés réservées aux secrets (D20) : jamais persistées, quelle que soit la
    // portée. La liste est volontairement conservatrice (tokens/proofs) ; le
    // reste de la mémoire est opaque et voyage tel quel.
    static const QStringList reservedSecretKeys = {
        QStringLiteral("token"),
        QStringLiteral("authToken"),
        QStringLiteral("sessionToken"),
        QStringLiteral("bearerToken"),
        QStringLiteral("password"),
        QStringLiteral("passwordHash"),
        QStringLiteral("proof"),
        QStringLiteral("secret"),
    };

    auto strip = [](QJsonObject scope) -> QJsonObject {
        for (const QString &key : reservedSecretKeys)
            scope.remove(key);
        return scope;
    };

    // Format MemoryStore::toJson : { version, session: {...}, players: { id: {...} } }.
    QJsonObject out = memory;
    if (out.contains(QStringLiteral("session")))
        out.insert(QStringLiteral("session"),
                   strip(out.value(QStringLiteral("session")).toObject()));
    if (out.contains(QStringLiteral("players"))) {
        QJsonObject players = out.value(QStringLiteral("players")).toObject();
        for (auto it = players.begin(); it != players.end(); ++it)
            it.value() = strip(it.value().toObject());
        out.insert(QStringLiteral("players"), players);
    }
    return out;
}

// ============================================================================
// Interne
// ============================================================================

QString GameSave::normalizeSaveName(const QString &name)
{
    // Même normalisation que les maps (lowercase, espaces → underscores) pour
    // une résolution de chemin stable ; le namespace reste séparé via le
    // dossier ./save/ et le suffixe _gamesave.json.
    QString normalized = name.toLower();
    normalized.replace(QLatin1Char(' '), QLatin1Char('_'));
    return normalized.trimmed();
}
