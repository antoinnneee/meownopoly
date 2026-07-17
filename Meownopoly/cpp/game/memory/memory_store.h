/*
 *      V3 / S-4 — Portée session + joueurs de l'espace mémoire (D15)
 *
 * Le doc v3/05 (§1, §6) tranche D15 : le contrat mémoire des tuiles
 * (`ItemSnapable::userMemory`, Étape A / tâche S-3) doit AUSSI pouvoir être
 * porté par la **session** et les **joueurs**. Cette brique fournit l'objet C++
 * manquant : un conteneur mémoire réutilisable (`MemoryScope`) et un agrégateur
 * (`MemoryStore`, singleton QML) qui possède la portée session + une portée par
 * joueur.
 *
 * Contrat mémoire (identique à ItemSnapable, doc v3/05 Étape A) :
 *   - QVariantMap opaque côté cœur (le sens des clés est une convention IA) ;
 *   - Q_PROPERTY `userMemory` réactive + signal global `userMemoryChanged` ;
 *   - setter fin `setMemoryValue(key, value)` + réveil ciblé
 *     `memoryValueChanged(ns, key, value, version)` où `ns` porte l'identité de
 *     la portée ("session" ou l'id du joueur) ;
 *   - garde anti-boucle réactive (D15) : aucune émission si la valeur est
 *     réellement inchangée ; garde de réentrance plafonnant les cascades.
 *
 * Plafonds D35 (doc v3/05 §3.2/§4) : 1 KB/valeur, 256 KB/portée. Dépassement =
 * rejet à la source (`quotaExceeded` émis, écriture ignorée, false renvoyé),
 * jamais de troncature silencieuse.
 *
 * Portée S-4 : le **modèle C++** et la persistance. Le transport host-authoritative
 * de l'état runtime (Étape B, bus d'état générique D35) et la compensation
 * transactionnelle (Étape C) sont hors périmètre — comme pour S-3 sur les tuiles.
 *
 * Note de conception (question ouverte doc v3/05 §6, « l'objet C++ exact pour la
 * session/joueur reste à concevoir ») : les portées joueur sont clés par un
 * `playerId` opaque (QString), PAS par un pointeur `Player*`. La mémoire d'un
 * joueur survit ainsi à la reconstruction de l'objet `Player` (réseau, reprise
 * de partie) et reste sérialisable indépendamment.
 */
#ifndef MEMORY_STORE_H
#define MEMORY_STORE_H

#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QStringList>
#include <QVariant>
#include <QVariantMap>

// ============================================================================
// MemoryScope — un espace mémoire réactif nommé (session, un joueur, …)
// ============================================================================
class MemoryScope : public QObject
{
    Q_OBJECT
    // Identité de la portée, injectée dans le `ns` des signaux ciblés.
    Q_PROPERTY(QString scopeName READ scopeName CONSTANT)
    // Blob de valeurs sérialisables, opaque côté cœur (convention IA pour les clés).
    Q_PROPERTY(QVariantMap userMemory READ userMemory WRITE setUserMemory
                   NOTIFY userMemoryChanged)

public:
    explicit MemoryScope(QString scopeName, QObject *parent = nullptr);

    QString scopeName() const { return m_scopeName; }

    QVariantMap userMemory() const { return m_userMemory; }
    void setUserMemory(const QVariantMap &memory);

    // Écrit une clé et émet un réveil ciblé memoryValueChanged. Renvoie false si
    // l'écriture est refusée (valeur inchangée : no-op silencieux ; plafond D35
    // dépassé : quotaExceeded émis ; cascade trop profonde).
    Q_INVOKABLE bool setMemoryValue(const QString &key, const QVariant &value);
    Q_INVOKABLE QVariant memoryValue(const QString &key) const { return m_userMemory.value(key); }
    Q_INVOKABLE bool contains(const QString &key) const { return m_userMemory.contains(key); }
    Q_INVOKABLE bool removeMemoryValue(const QString &key);
    Q_INVOKABLE QStringList keys() const { return m_userMemory.keys(); }
    Q_INVOKABLE void clear();

    // --- Persistance (M7 GameSave, T4-2) ---
    // Le blob voyage dans la sauvegarde de partie via ces deux méthodes ; aucun
    // schéma de clés imposé (comme ItemSnapable::toJSON/applyJson).
    QJsonObject toJson() const;
    void loadJson(const QJsonObject &memory);

    // Taille estimée du blob en octets (JSON compact), pour les plafonds D35.
    int estimatedSizeBytes() const;

signals:
    // Réveil global : toute la portée a changé (support de l'usage 3, doc v3/05 §1).
    void userMemoryChanged();
    // Réveil ciblé sur une clé sans re-scanner la map. `ns` = scopeName ; `version`
    // est un compteur d'écriture monotone qui aide à ignorer les états obsolètes.
    void memoryValueChanged(const QString &ns, const QString &key,
                            const QVariant &value, int version);
    // Émis quand une écriture dépasse un plafond D35 (`reason` ∈ {"value", "scope"}).
    // L'écriture est refusée (pas de troncature silencieuse).
    void quotaExceeded(const QString &ns, const QString &key, const QString &reason);

private:
    QString     m_scopeName;
    QVariantMap m_userMemory;
    quint32     m_memoryVersion   = 0;
    int         m_memoryWriteDepth = 0;

    // Plafonds D35 (doc v3/05 §3.2). 1 KB/valeur, 256 KB/portée.
    static constexpr int kMaxValueBytes        = 1024;
    static constexpr int kMaxScopeBytes        = 256 * 1024;
    static constexpr int kMaxMemoryCascadeDepth = 16;

    static int variantSizeBytes(const QVariant &value);
};

// ============================================================================
// MemoryStore — agrégateur singleton : portée session + une portée par joueur
// ============================================================================
class MemoryStore : public QObject
{
    Q_OBJECT
    // Portée mémoire de la session (persistante avec la partie).
    Q_PROPERTY(MemoryScope *session READ session CONSTANT)
    Q_PROPERTY(QStringList playerIds READ playerIds NOTIFY playersChanged)

public:
    static void registerQml();
    static MemoryStore *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    // Nom réservé de la portée session (préfixe distinct des ids joueurs).
    static QString sessionScopeName() { return QStringLiteral("session"); }

    MemoryScope *session() const { return m_session; }

    // Portée d'un joueur, créée à la demande si absente. `playerId` est un id
    // opaque et stable (nom réseau / uuid joueur), pas un pointeur Player*.
    Q_INVOKABLE MemoryScope *player(const QString &playerId);
    // Portée d'un joueur si elle existe déjà (sans la créer), sinon nullptr.
    Q_INVOKABLE MemoryScope *playerIfExists(const QString &playerId) const;
    Q_INVOKABLE bool hasPlayer(const QString &playerId) const { return m_players.contains(playerId); }
    Q_INVOKABLE bool removePlayer(const QString &playerId);
    QStringList playerIds() const { return m_players.keys(); }

    // Raccourcis session.
    Q_INVOKABLE bool setSessionValue(const QString &key, const QVariant &value);
    Q_INVOKABLE QVariant sessionValue(const QString &key) const;

    // Raccourcis joueur (crée la portée à la demande).
    Q_INVOKABLE bool setPlayerValue(const QString &playerId, const QString &key,
                                    const QVariant &value);
    Q_INVOKABLE QVariant playerValue(const QString &playerId, const QString &key) const;

    // Remise à zéro complète (nouvelle partie) : vide la session et supprime
    // toutes les portées joueur.
    Q_INVOKABLE void reset();

    // --- Persistance (M7 GameSave, T4-2) ---
    // Format : { version, session: {…}, players: { "<id>": {…} } }.
    QJsonObject toJson() const;
    void loadJson(const QJsonObject &obj);
    // Variantes QML-friendly (QVariantMap) des mêmes I/O.
    Q_INVOKABLE QVariantMap toVariantMap() const;
    Q_INVOKABLE void loadVariantMap(const QVariantMap &map);

signals:
    // Relais des réveils ciblés de toutes les portées (session + joueurs), avec
    // l'identité de la portée dans `ns`. Point d'abonnement unique pour l'IA/règles.
    void memoryValueChanged(const QString &ns, const QString &key,
                            const QVariant &value, int version);
    // Relais des dépassements de plafond (D35).
    void quotaExceeded(const QString &ns, const QString &key, const QString &reason);
    void playersChanged();
    void playerAdded(const QString &playerId);
    void playerRemoved(const QString &playerId);

private:
    explicit MemoryStore(QObject *parent = nullptr);

    // Câble les relais d'une portée vers les signaux agrégés du store.
    void wireScope(MemoryScope *scope);

    static MemoryStore *m_instance;

    static constexpr int kSchemaVersion = 1;

    MemoryScope                    *m_session = nullptr;
    QHash<QString, MemoryScope *>   m_players;
};

#endif // MEMORY_STORE_H
