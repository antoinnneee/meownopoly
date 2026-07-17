#ifndef STATIC_VALIDATOR_H
#define STATIC_VALIDATOR_H

// ============================================================================
// StaticValidator — préfiltre statique P0 des artefacts QML/JS
// (doc/v3/12_BANC_ESSAI_R1.md §3, doc/v3/04_QML_GENERATIF_SANDBOX.md §3.1,
//  décisions D34 (allow-list + budgets) et D41 (requiresModules),
//  tâche A4 du plan doc/v3/15_PLAN_IMPLEMENTATION.md).
//
// Rôle : valider tout artefact candidat AVANT de payer un process de banc
// (P1→P5). S'exécute dans le jeu — toujours chez l'hôte (fait foi) et en
// best-effort chez l'auteur (fail-fast). Même code aux deux endroits.
//
// Contraintes : QtCore uniquement (linkable dans le jeu, le banc et les
// tests, aucune dépendance réseau/GUI/moteur QML). CRITIQUE sécurité :
// échec fermé — tout cas indécidable produit un fail, jamais une exception.
//
// ---------------------------------------------------------------------------
// Choix d'implémentation du contrôle « parse » (documenté, cf. tâche A4) :
// P0 ne crée PAS de QQmlEngine (Qt 6.11 : QQmlComponent exige un engine, et
// instancier un moteur dans le jeu pour chaque proposition serait payer au
// mauvais étage). P0 fait une analyse lexicale/structurelle propre :
//   - blanking des commentaires et littéraux de chaîne (tokenizer minimal,
//     interpolations ${...} des template literals conservées comme code) ;
//   - équilibre des {} () [] (pile) ;
//   - présence d'un objet racine QML (Type débutant par une majuscule + '{')
//     après les lignes import/pragma.
// Le parse QML complet reste l'affaire du banc (P2, load_failed) — P0 est un
// grossier fail-fast, le banc fait foi.
// ---------------------------------------------------------------------------
//
// CODES D'ERREUR STABLES (remontent tels quels à l'IA cliente, doc 12 §4 —
// ne jamais renommer sans bump de version de protocole) :
//
// | code                     | retryable | déclencheur                        |
// |--------------------------|-----------|------------------------------------|
// | source_too_large         | non | source > MEOW_SANDBOX_MAX_SOURCE_KB KB  |
// | parse_failed             | non | lexique/structure invalide (chaîne ou   |
// |                          |     | commentaire non terminé, {}()[] non     |
// |                          |     | équilibrés, pas d'objet racine, vide)   |
// | import_forbidden         | non | import hors allow-list D34, sous-import |
// |                          |     | d'un module interdit, ou import de      |
// |                          |     | fichier ("….js"/dossier)                |
// | js_forbidden             | non | token JS interdit hors chaîne/commentaire :  |
// |                          |     | XMLHttpRequest, Qt.openUrlExternally,   |
// |                          |     | Qt.createQmlObject, Qt.createComponent, |
// |                          |     | eval(, Function(, import( dynamique     |
// | timer_interval_too_low   | non | Timer { interval: <littéral> } avec     |
// |                          |     | littéral < MEOW_SANDBOX_TIMER_MIN_MS    |
// | missing_module           | OUI | module de requiresModules absent/inactif|
// |                          |     | dans le contexte (D41)                  |
// | validator_internal       | non | erreur interne du validateur —          |
// |                          |     | échec fermé, jamais de pass par défaut  |
// ============================================================================

#include <QJsonObject>
#include <QList>
#include <QString>
#include <QStringList>

// ----------------------------------------------------------------------------
// Constantes (pattern D22 : surchargeables à la compilation via -D).
// ----------------------------------------------------------------------------

// Taille max de la source d'un artefact, en KB (budget D34 : « source ≤ 20 KB »).
#ifndef MEOW_SANDBOX_MAX_SOURCE_KB
#define MEOW_SANDBOX_MAX_SOURCE_KB 20
#endif

// Plancher des Timer QML, en ms (budget D34 : « Timer ≥ 100 ms »).
// P0 n'attrape que les littéraux entiers `interval: N` — un interval calculé
// (binding, expression) passe P0 et sera attrapé au banc (P4, event_flood).
#ifndef MEOW_SANDBOX_TIMER_MIN_MS
#define MEOW_SANDBOX_TIMER_MIN_MS 100
#endif

// Une défaillance de validation. `code` est stable (table ci-dessus),
// `message` est une phrase courte, `details` le complément actionnable
// (exploitable par un LLM, doc 12 §4).
struct ValidationFailure
{
    QString code;
    QString message;
    QString details;
    bool retryable = false;

    QJsonObject toJson() const;
};

// Résultat complet du P0. `listensTo` (hooks `events.on("<type>", …)`
// détectés statiquement) alimente la génération des stimuli P4 (doc 12 §3).
// `sourceHash` (SHA-256 hex de la source UTF-8) est la clé du cache de
// verdicts (doc 12 §7) — calculé même quand la validation échoue.
struct ValidationResult
{
    bool ok = false;
    QList<ValidationFailure> failures;
    QStringList listensTo;
    QStringList imports;
    QString sourceHash;

    QJsonObject toJson() const;
};

class StaticValidator
{
public:
    // Valide `source` (texte QML/JS de l'artefact) dans `context` :
    //   {
    //     "requiresModules": ["stats", ...],   // déclarés par l'enveloppe (D41)
    //     "modules": { "stats": true, ... },   // état d'activation sur la map
    //     "extraAllowedImports": ["Meow.Snapables", ...] // optionnel :
    //         modules custom du jeu énumérés par le manifeste (D34)
    //   }
    // Tous les champs du contexte sont optionnels (absents = vides).
    // Ne lève jamais : toute erreur interne → fail `validator_internal`.
    ValidationResult validate(const QString &source,
                              const QJsonObject &context) const;
};

#endif // STATIC_VALIDATOR_H
