/*
 *      V3 / T4-4 — Rulebook (D8/D12) : règlement structuré versionné
 *
 * Modèle de DONNÉES pur (aucun QObject) du règlement de partie, cadré par
 * doc v3/06 §5. Le règlement autoritatif n'est PAS le prompt de l'arbitre :
 * c'est ce document, tenu par l'hôte (RulesEngine), sérialisable pour la
 * sauvegarde de partie (M7/T4-2), le checkpoint de migration (D37/T4-3) et
 * l'audit (D19).
 *
 *  - `Rulebook.version` est le compteur monotone qui alimente le champ
 *    `rulebook` de `baseVersion` des enveloppes de proposition (doc 13 §3,
 *    détection stale_base déjà câblée dans proposal_lifecycle.cpp) ;
 *  - chaque `Rule` porte une FORME de l'échelle D12 (la moins libre
 *    suffisante, D32) : `module` (config de primitive GameplayModuleManager),
 *    `dsl` (déclencheur + conditions + effets bornés), `artifact` (référence
 *    à un artefact QML/JS validé au banc — jamais exécuté ici) ;
 *  - l'origine (`originProposalId`, `author`) trace la proposition/l'amendement
 *    D11 dont la règle est issue.
 *
 * La numérotation/valeurs de chaîne sont PERSISTÉES (save + checkpoint) : ne
 * jamais renommer une valeur de `form`/`op`/`action` publiée, seulement en
 * ajouter (bump kRulebookSchemaVersion si le format change).
 */
#ifndef MEOW_RULEBOOK_H
#define MEOW_RULEBOOK_H

#include <QJsonArray>
#include <QJsonObject>
#include <QList>
#include <QString>
#include <QStringList>
#include <QVariant>
#include <QVariantMap>

namespace meow::rules {

// Version du schéma du document (champ `schemaVersion`).
inline constexpr int kRulebookSchemaVersion = 1;

// Plafonds de forme (protections §5.5 — bornes d'un DOCUMENT, les cascades
// runtime sont bornées par les garde-fous D12 du bus).
inline constexpr int kMaxRules             = 256;
inline constexpr int kMaxConditionsPerRule = 16;
inline constexpr int kMaxEffectsPerRule    = 16;

// Formes exécutables D12 (doc 06 §5.2). Chaînes persistées.
namespace form {
inline const QString kModule   = QStringLiteral("module");
inline const QString kDsl      = QStringLiteral("dsl");
inline const QString kArtifact = QStringLiteral("artifact");
} // namespace form

// ----------------------------------------------------------------------------
// RuleCondition — une condition du DSL borné (ET logique entre conditions).
//   source : "event.<champ>"                (champ du payload de l'événement ;
//                                            "event.type" = nom canal)
//            "memory.session.<clé>"         (portée session, MemoryStore)
//            "memory.player.<id>.<clé>"     (portée joueur)
//            "memory.tile.<uuid>.<clé>"     (mémoire d'une tuile, S-3)
//   op     : eq | neq | lt | lte | gt | gte | contains | exists | missing
// ----------------------------------------------------------------------------
struct RuleCondition {
    QString  source;
    QString  op = QStringLiteral("eq");
    QVariant value;             // opérande droit (absent pour exists/missing)

    bool isValid(QString *error = nullptr) const;

    static RuleCondition fromJson(const QJsonObject &o);
    QJsonObject toJson() const;
};

// ----------------------------------------------------------------------------
// RuleEffect — un effet du DSL borné (actions fermées, doc 06 §5.2) :
//   memory.set     args { scope: session|player|tile, playerId?, uuid?, key, value }
//   event.emit     args { name, payload? }   (→ événement "rule.event" du bus)
//   module.config  args { id, enabled }      (→ GameplayModuleManager)
// ----------------------------------------------------------------------------
struct RuleEffect {
    QString     action;
    QVariantMap args;

    bool isValid(QString *error = nullptr) const;

    static RuleEffect fromJson(const QJsonObject &o);
    QJsonObject toJson() const;
};

// ----------------------------------------------------------------------------
// Rule — une règle du règlement.
// ----------------------------------------------------------------------------
struct Rule {
    QString id;                 // uuid (généré si absent)
    QString title;              // libellé court
    QString notes;              // vue lisible choisie par l'arbitre (D8)
    QString form;               // form::kModule | form::kDsl | form::kArtifact
    bool    enabled = true;

    // Déclencheur (formes dsl/artifact) : nom canal Q-E06 ("tile.placed",
    // "memory.changed", "combat.resolved", "game.tick", …) ou "*".
    QString trigger;
    QList<RuleCondition> conditions;   // ET logique (forme dsl)
    QList<RuleEffect>    effects;      // forme dsl

    // Forme module : primitive GameplayModuleManager (D12/D41).
    QString moduleId;
    bool    moduleEnabled = true;

    // Forme artifact : référence à un artefact validé au banc (D26/D32).
    // Le moteur ne l'exécute pas — il publie rule.triggered (doc 06 §5.2).
    QString artifactHash;       // "sha256:…"
    QString artifactUuid;       // tuile porteuse (optionnel)

    // Origine / audit (D11 : proposition ET forme appliquée persistées).
    QString originProposalId;
    QString author;

    bool isValid(QString *error = nullptr) const;

    static Rule fromJson(const QJsonObject &o);
    QJsonObject toJson() const;
};

// ----------------------------------------------------------------------------
// Rulebook — le document complet.
// ----------------------------------------------------------------------------
struct Rulebook {
    int     schemaVersion = kRulebookSchemaVersion;
    qint64  version       = 0;   // compteur monotone hôte (= baseVersion.rulebook)
    QString title;
    QList<Rule> rules;

    int indexOfRule(const QString &ruleId) const;

    // Round-trip JSON. `fromJson` refuse (retour false + `error`) un schéma
    // plus récent que le courant ou un document hors bornes.
    static bool fromJson(const QJsonObject &o, Rulebook &out, QString &error);
    QJsonObject toJson() const;
};

} // namespace meow::rules

#endif // MEOW_RULEBOOK_H
