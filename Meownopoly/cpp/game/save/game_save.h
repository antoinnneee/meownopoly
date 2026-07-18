/*
 *      Meownopoly V3 — M7 · Sauvegarde de partie (T4-2, D27)
 *
 * D27 (doc v3/08) tranche : l'état runtime pour **reprendre une partie** vit
 * dans une sauvegarde **distincte du fichier map**. La map reste un *contenu*
 * rejouable/partageable ; la partie est une *instance*. Mélanger les deux
 * polluerait le format map et rendrait ambigu le chargement dans l'éditeur.
 *
 * Cette brique fournit le **format** de la sauvegarde et son I/O atomique.
 * Elle est volontairement découplée des singletons de jeu : elle assemble des
 * sous-objets déjà sérialisés (mémoire, modules, joueurs, artefacts, horloges)
 * et n'impose aucun schéma à leur contenu — le sens des clés est une
 * convention métier/IA, comme pour `ItemSnapable::toJSON`.
 *
 * Ce que porte une sauvegarde (D27) :
 *   - une **référence** vers la map ({ id, version, hash }), jamais la map
 *     elle-même — le contenu reste dans son fichier `*_map.json` ;
 *   - le **règlement versionné** (`rulebook`, opaque ici — matérialisé par
 *     T4-4) ;
 *   - le namespace `state`/`config` des **mémoires** (session + joueurs,
 *     `MemoryStore::toJson`, doc v3/05 D15) ;
 *   - l'état des **joueurs** ;
 *   - l'état d'activation des **modules** de gameplay (D41) ;
 *   - les **artefacts actifs** ({ instanceId, contentHash, manifestVersion },
 *     D16/D36 — les hashes réels viennent du store T4-1) ;
 *   - les **horloges/séquences** logiques (Lamport, seq réseau…), pour que la
 *     reprise ne collisionne pas avec l'historique.
 *
 * Espace de nommage **séparé** des cartes (D27) : les sauvegardes vivent sous
 * `./save/` avec le suffixe `.gamesave.json`, jamais dans `./map/` ni sous les
 * sentinelles `autosave_tmp` / `<nom>_map.json`. Une sauvegarde n'est **pas**
 * un `MapTypes::MapType` — elle a son propre type et sa propre version de
 * schéma.
 *
 * Secrets (D20) : la sauvegarde **exclut** tout secret (tokens de session,
 * proofs de mot de passe…). Ces valeurs ne transitent jamais par la mémoire
 * persistée ; `sanitizeSecrets` retire par prudence les clés réservées d'un
 * blob mémoire avant écriture. Le chiffrement au repos, s'il devient requis,
 * s'ajoute au-dessus de ce format sans en changer le schéma.
 *
 * I/O atomique : même patron que `MapFileManager::saveMap`
 * (`mapfilemanager.cpp:261-284`) — écriture dans `<path>.tmp` puis `rename`,
 * sous `QLockFile`, pour ne jamais laisser un fichier à moitié écrit.
 */
#ifndef GAME_SAVE_H
#define GAME_SAVE_H

#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QStringList>
#include <QVariantMap>

#define GAME_SAVE_PATH "./save/"
#define GAME_SAVE_SUFFIX "_gamesave.json"

/// Référence vers la map jouée. Ne porte jamais le contenu : { id, version,
/// hash } suffit à retrouver le bon fichier map et à détecter qu'il a changé
/// depuis la sauvegarde (le `hash` couvre l'intégrité, la `version` la lignée).
struct GameSaveMapRef
{
    QString id;         ///< Identité stable de la map (nom normalisé par défaut).
    int     version = 0;///< `MapInfo::version` au moment de la sauvegarde.
    QString hash;       ///< "sha256:<hex>" du JSON de map compact (vide si inconnu).

    QJsonObject toJson() const;
    static GameSaveMapRef fromJson(const QJsonObject &obj);
    bool isValid() const { return !id.isEmpty(); }
};

/// Sauvegarde de partie V3 (M7). QObject pour l'usage QML éventuel ; l'essentiel
/// de l'API est statique/sans état pour être testable hors scène (banc, CI).
class GameSave : public QObject
{
    Q_OBJECT

    // Surface QML minimale : identité + horodatage + référence map.
    Q_PROPERTY(int saveVersion READ saveVersion CONSTANT)
    Q_PROPERTY(QString saveId READ saveId NOTIFY changed)
    Q_PROPERTY(QString saveName READ saveName WRITE setSaveName NOTIFY changed)

public:
    /// Version courante du schéma de sauvegarde. Bump à tout changement
    /// incompatible ; le lecteur refuse `saveVersion > CURRENT_SAVE_VERSION`.
    static constexpr int CURRENT_SAVE_VERSION = 1;

    explicit GameSave(QObject *parent = nullptr);

    // Enregistrement QML (non câblé dans qmlapp.cpp à ce stade — l'intégration
    // du chargement en jeu appellera registerQml au moment voulu, T4-3/T4-5).
    static void registerQml();

    // ── Identité / métadonnées ─────────────────────────────────────────────
    int saveVersion() const { return CURRENT_SAVE_VERSION; }
    QString saveId() const { return m_saveId; }
    QString saveName() const { return m_saveName; }
    void setSaveName(const QString &name);

    // ── Contenu (sous-objets déjà sérialisés, opaques) ─────────────────────
    void setMapRef(const GameSaveMapRef &ref) { m_mapRef = ref; Q_EMIT changed(); }
    GameSaveMapRef mapRef() const { return m_mapRef; }

    void setRulebook(const QJsonObject &rulebook) { m_rulebook = rulebook; Q_EMIT changed(); }
    QJsonObject rulebook() const { return m_rulebook; }

    /// Blob mémoire (format `MemoryStore::toJson` : { version, session, players }).
    /// Les secrets réservés sont retirés à l'écriture (sanitizeSecrets).
    void setMemory(const QJsonObject &memory) { m_memory = memory; Q_EMIT changed(); }
    QJsonObject memory() const { return m_memory; }

    void setPlayers(const QJsonArray &players) { m_players = players; Q_EMIT changed(); }
    QJsonArray players() const { return m_players; }

    /// État d'activation des modules (`GameplayModuleManager::moduleStateJson`).
    void setModules(const QJsonObject &modules) { m_modules = modules; Q_EMIT changed(); }
    QJsonObject modules() const { return m_modules; }

    /// Artefacts actifs : tableau de { instanceId, contentHash, manifestVersion }.
    /// Les `contentHash` réels sont fournis par le store d'artefacts (T4-1) ;
    /// tant qu'il n'existe pas, le tableau peut rester vide sans casser le format.
    void setArtifacts(const QJsonArray &artifacts) { m_artifacts = artifacts; Q_EMIT changed(); }
    QJsonArray artifacts() const { return m_artifacts; }

    /// Horloges/séquences logiques (ex: { lamport: N, sequences: { … } }).
    void setClocks(const QJsonObject &clocks) { m_clocks = clocks; Q_EMIT changed(); }
    QJsonObject clocks() const { return m_clocks; }

    // ── Sérialisation ──────────────────────────────────────────────────────
    /// Objet JSON complet, prêt à écrire. Secrets retirés du blob mémoire.
    QJsonObject toJson() const;
    /// Charge depuis un objet JSON. Retourne false si `saveVersion` est absent
    /// ou plus récent que `CURRENT_SAVE_VERSION` (schéma non compris).
    bool loadJson(const QJsonObject &obj);
    /// Variantes QML-friendly.
    Q_INVOKABLE QVariantMap toVariantMap() const;
    Q_INVOKABLE bool loadVariantMap(const QVariantMap &map);

    // ── Assemblage de commodité ────────────────────────────────────────────
    /// Renseigne mémoire + modules depuis les singletons du jeu (headless-safe).
    /// Les joueurs, artefacts, horloges et référence map restent à la charge de
    /// l'appelant (dépendent du contexte de partie, non d'un singleton global).
    Q_INVOKABLE void captureRuntimeState();

    // ── I/O fichier (atomique, .tmp + rename sous QLockFile) ────────────────
    /// Écrit la sauvegarde sous `./save/<nom>_gamesave.json`. Atomique.
    Q_INVOKABLE bool saveToFile(const QString &saveName) const;
    /// Recharge la sauvegarde de nom donné dans cette instance.
    Q_INVOKABLE bool loadFromFile(const QString &saveName);

    // Utilitaires statiques (sans instance).
    static bool writeSave(const QJsonObject &data, const QString &saveName);
    static QJsonObject readSave(const QString &saveName);
    static bool removeSave(const QString &saveName);
    static bool saveExists(const QString &saveName);
    static QStringList availableSaves();
    static QString saveFilePath(const QString &saveName);

    /// "sha256:<hex>" du JSON compact (clés triées → forme canonique). Sert au
    /// hash de map de `GameSaveMapRef` comme à toute empreinte de contenu.
    static QString computeContentHash(const QJsonObject &obj);
    /// Construit la référence map depuis son MapInfo (id/version) et le JSON de
    /// map complet (hash). `mapJson` vide → hash vide (référence encore valide).
    static GameSaveMapRef buildMapRef(const QString &mapId, int version,
                                      const QJsonObject &mapJson);

    /// Retire d'un blob mémoire les clés réservées aux secrets, à toutes les
    /// portées. Ne mute pas l'entrée ; renvoie une copie assainie.
    static QJsonObject sanitizeSecrets(const QJsonObject &memory);

signals:
    void changed();

private:
    static QString normalizeSaveName(const QString &name);

    QString        m_saveId;      ///< UUID stable de la sauvegarde.
    QString        m_saveName;    ///< Nom lisible (dérive le nom de fichier).
    QString        m_createdAt;   ///< ISO 8601 UTC, figé à la création.
    QString        m_lastSavedAt; ///< ISO 8601 UTC, réécrit à chaque toJson.
    GameSaveMapRef m_mapRef;
    QJsonObject    m_rulebook;
    QJsonObject    m_memory;
    QJsonArray     m_players;
    QJsonObject    m_modules;
    QJsonArray     m_artifacts;
    QJsonObject    m_clocks;
};

#endif // GAME_SAVE_H
