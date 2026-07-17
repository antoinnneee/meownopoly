/*
 *      V3 / Phase 2 — S-2 · Verdict à deux audiences (doc v3 13 §4)
 *
 * Le VERDICT est le document que l'arbitre (D6/D25/D32) rend sur une
 * proposition en `arbitrating`. Contrairement à l'issue simple (enum
 * VerdictOutcome) consommée par la machine à états en S-1, ce document porte
 * TOUT ce dont ont besoin les deux publics :
 *   - le JOUEUR : une phrase lisible affichée dans le tchat (`audience=player`) ;
 *   - l'IA      : un code stable + une consigne actionnable + `retryable`
 *                 (`audience=ai`) — c'est la condition du scénario S3 (rejet →
 *                 itération dans le même tour).
 *
 * L'amendement (D32) est un PATCH (ops/artefacts remplacés/ajoutés/retirés),
 * jamais une ré-enveloppe : l'original reste intact au journal (D11). Le
 * `benchReport` d'un amendement de code référence le NOUVEAU passage au banc.
 *
 * Modèle de DONNÉES pur (aucun QObject) : il vit à côté de l'enveloppe et se
 * sérialise en round-trip pour le journal (D19) et le retour MCP (doc 13 §5).
 */
#ifndef MEOW_PROPOSAL_VERDICT_H
#define MEOW_PROPOSAL_VERDICT_H

#include <QJsonArray>
#include <QJsonObject>
#include <QList>
#include <QString>
#include <QVariantMap>

#include "proposal_envelope.h" // BaseVersion
#include "proposal_types.h"    // VerdictOutcome

namespace meow::proposal {

// Audiences reconnues d'une raison de verdict (doc 13 §4).
QString audiencePlayer();
QString audienceAi();

// Une raison de verdict, adressée à un public. `code` et `retryable` n'ont de
// sens réel que pour l'audience `ai` (le joueur ne voit que `text`).
struct VerdictReason {
    QString audience;            // "player" | "ai"
    QString code;                // code mécanique/contextuel stable (surtout ai)
    QString text;                // phrase lisible / consigne actionnable
    bool    retryable = false;   // l'IA peut-elle re-proposer après correction ?

    QJsonObject toJson() const;
    static VerdictReason fromJson(const QJsonObject &o);
};

// Amendement (D32) : un PATCH, pas une ré-enveloppe (doc 13 §4).
struct VerdictAmendment {
    QJsonArray operationsPatch;  // ops remplacées / ajoutées / retirées
    QJsonArray artifactsPatch;   // { contentHash, source }…
    QString    note;             // justification humaine ("cooldown 5 s ajouté")

    bool isEmpty() const;
    QJsonObject toJson() const;
    static VerdictAmendment fromJson(const QJsonObject &o);
};

// Rapport du banc d'essai (D26) référencé par le verdict. Pour un amendement de
// code, référence le NOUVEAU passage (D32).
struct BenchReport {
    QString verdict;    // "pass" | "fail" | vide (non passé au banc)
    QString metricsRef; // ex. "journal seq 1051"

    bool isSet() const { return !verdict.isEmpty(); }
    QJsonObject toJson() const;
    static BenchReport fromJson(const QJsonObject &o);
};

// Le verdict complet (doc 13 §4).
struct Verdict {
    QString        proposalId;
    VerdictOutcome outcome = VerdictOutcome::Rejected;
    QJsonObject    decidedBy;     // { role: "arbiter", agent: {…} }
    QList<VerdictReason> reasons;
    VerdictAmendment amendment;
    BenchReport      benchReport;
    BaseVersion      appliedVersion; // versions résultantes (Q-E06)
    QString          decidedAt;      // ISO-8601

    // Présence d'un patch d'amendement (branche `amended` de la machine).
    bool hasAmendment() const { return amendment.isEmpty() ? false : true; }

    // Concaténation des raisons `audience=player` (une seule phrase pour le
    // tchat). Vide si aucune raison joueur.
    QString playerText() const;
    // Première raison `audience=ai` (code + consigne). Vide si aucune.
    VerdictReason aiReason() const;

    // Objet retourné au tool MCP bloquant (doc 13 §5) : `verdict`,
    // `reasons[audience=ai]`, et — si amendé — le diff résumé de l'amendement.
    QVariantMap toMcpReturn() const;

    // Sérialisation journal (D19), round-trip complet.
    QJsonObject toJson() const;
    // `error` renseigné et retour false si la forme est invalide (verdict
    // manquant/inconnu, audience inconnue). Le `proposalId` porté par le JSON
    // fait foi s'il est présent.
    static bool fromJson(const QJsonObject &o, Verdict &out, QString &error);
    static bool fromVariantMap(const QVariantMap &m, Verdict &out, QString &error);
};

} // namespace meow::proposal

#endif // MEOW_PROPOSAL_VERDICT_H
