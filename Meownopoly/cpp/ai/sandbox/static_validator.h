#ifndef MEOW_STATIC_VALIDATOR_H
#define MEOW_STATIC_VALIDATOR_H

// ============================================================================
// static_validator — préfiltre statique P0 in-game du sandbox QML (D26/D34/D41)
// ============================================================================
//
// Spécification : doc/v3/12_BANC_ESSAI_R1.md §3 (phase P0),
//                 doc/v3/04_QML_GENERATIF_SANDBOX.md §3.1,
//                 doc/v3/08_DECISIONS_ET_QUESTIONS.md D34 (allow-list) / D41
//                 (requiresModules).
//
// Rôle : **premier point de passage mécanique** de tout artefact QML/JS candidat,
// AVANT même de spawner le banc d'essai hors-process (doc 12 §3 : « inutile de
// payer un process pour un import interdit »). Contrôles purement statiques :
//   1. taille de la source ≤ 20 KB (D34) ;
//   2. allow-list d'imports (D34) — rejet de tout module hors liste ;
//   3. interdits statiques (D34 §3.1) — XMLHttpRequest, Qt.openUrlExternally,
//      Qt.createQmlObject imbriqué, FileDialog, Process, imports de fichiers JS
//      arbitraires… ;
//   4. dépendances de modules (D41) — un `requiresModules` non satisfait (ni
//      actif sur la map, ni activé par une opération du même lot) est rejeté
//      `missing_module`.
//
// **Même code hôte + auteur** (doc 12 §3, précision collab) : ce validateur
// tourne chez l'auteur avant l'envoi (fail-fast, best-effort) ET chez l'hôte à
// réception — c'est le P0 de l'hôte qui **fait foi**. Ne dépend que de
// Qt6::Core (QString/QRegularExpression/QJson) — aucun module réseau, aucune
// instanciation QML : l'analyse est **lexicale** (pas d'exécution de code
// hostile). Un artefact qui passe P0 n'est pas « accepté » : il part au banc
// (P1→P5) puis à l'arbitre.
//
// Livrable de la tâche A4 (« préfiltre P0 static_validator », plan v3 doc 15).
// ============================================================================

#include <QString>
#include <QStringList>
#include <QSet>
#include <QList>
#include <QJsonObject>

// Taille max de la source d'un artefact (D34 : ≤ 20 KO ; doc 12 §9). Derrière
// #define (pattern D22) pour recalibrage sans toucher au code.
#ifndef MEOW_STATIC_MAX_SOURCE_BYTES
#define MEOW_STATIC_MAX_SOURCE_BYTES 20480
#endif

namespace meow::sandbox {

// ─── Codes d'échec P0 (stables) ─────────────────────────────────────────────
// Comme les codes du banc (bench_protocol), ils sont destinés à être documentés
// dans le manifeste du canal (allowListRef) et remontent tels quels à l'IA
// cliente (S3 : le rejet doit être actionnable). `missing_module` est le code
// exact figé par D41.
namespace failure {
    inline constexpr char kSourceTooLarge[]     = "source_too_large";
    inline constexpr char kImportForbidden[]    = "import_forbidden";
    inline constexpr char kForbiddenConstruct[] = "forbidden_construct";
    inline constexpr char kQmlParseError[]      = "qml_parse_error";
    inline constexpr char kMissingModule[]      = "missing_module";
} // namespace failure

// ─── Résultat ───────────────────────────────────────────────────────────────
struct StaticFinding {
    QString code;              // failure::k*
    QString details;           // phrase exploitable par un LLM (S3)
    bool    retryable = true;  // P0 est mécanique → presque tout est corrigeable

    QJsonObject toJson() const;
};

struct StaticValidationInput {
    // Source QML/JS de l'artefact (champ `artifact.source` de l'enveloppe).
    QString source;

    // Modules déclarés nécessaires par l'artefact (`requiresModules`, doc 13 §3).
    QStringList requiresModules;

    // Modules gameplay actuellement actifs sur la map (snapshot.modules, D41).
    QSet<QString> activeModules;

    // Modules activés par une opération `module_config(enabled=true)` du **même
    // lot atomique** (D41 : « ni actif sur la map ni activé par une opération du
    // même lot »). L'appelant les extrait des `operations[]` de l'enveloppe.
    QSet<QString> batchActivatedModules;

    // Modules QML custom du jeu autorisés en plus de la base (D34 : « énumérés
    // dans le manifeste »). MVP : vide tant que le manifeste ne les matérialise
    // pas (allowListRef.status). Ex. futur : "MeowComponents".
    QStringList extraAllowedImports;
};

struct StaticValidationResult {
    QList<StaticFinding> findings;   // vide ⇒ P0 passé
    QStringList          imports;    // modules importés détectés (diagnostic)

    bool passed() const { return findings.isEmpty(); }
    QJsonObject toJson() const;      // { passed, findings:[…], imports:[…] }
};

// ─── Validateur ─────────────────────────────────────────────────────────────
class StaticValidator {
public:
    // Point d'entrée unique. Ne lève jamais ; agrège **toutes** les violations
    // trouvées (l'IA corrige d'un coup, pas erreur par erreur).
    static StaticValidationResult validate(const StaticValidationInput &in);

    // Allow-list d'imports de base (D34), hors modules custom du manifeste.
    static QStringList baseAllowedImports();

    // Helpers exposés pour test / réutilisation (analyse lexicale) :
    // retire commentaires et, si `removeStrings`, littéraux de chaîne
    // (", ', `). `*wellTerminated` (optionnel) = false si un littéral ou un
    // commentaire bloc reste ouvert en fin de source (→ qml_parse_error).
    static QString sanitize(const QString &src, bool removeStrings,
                            bool *wellTerminated = nullptr);

    // Extrait les identifiants de modules des lignes `import …` (source déjà
    // décommentée mais chaînes conservées). Un import de fichier/JS entre
    // guillemets est renvoyé tel quel (avec son guillemet ouvrant) pour être
    // rejeté par validate().
    static QStringList extractImports(const QString &sourceNoComments);
};

} // namespace meow::sandbox

#endif // MEOW_STATIC_VALIDATOR_H
