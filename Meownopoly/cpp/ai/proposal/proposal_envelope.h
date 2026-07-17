/*
 *      V3 / Phase 2 — S-1 · Enveloppe de proposition (doc v3 13 §3)
 *
 * Conteneur unique d'une intention de modification de l'état partagé (D11).
 * Sérialisation JSON round-trip (`envelopeVersion: 1`) + calcul MÉCANIQUE, par
 * le P0, du `requestType` et du `writeSet` global (jamais repris des champs
 * déclarés par l'auteur — plancher D25 non contournable, doc 13 §3).
 *
 * Cette structure est un modèle de DONNÉES pur (aucun QObject) : elle est
 * partagée entre l'hôte (P0 fait foi) et l'auteur (P0 fail-fast local). Le
 * cycle de vie (états, file, transitions) vit dans proposal_lifecycle.
 */
#ifndef MEOW_PROPOSAL_ENVELOPE_H
#define MEOW_PROPOSAL_ENVELOPE_H

#include <QJsonArray>
#include <QJsonObject>
#include <QString>
#include <QStringList>

#include "proposal_types.h"

namespace meow::proposal {

// Identité de l'auteur (roster + agent CLI). `agent` reste un objet opaque
// (cli/model/sessionId) — non interprété par le P0.
struct Author {
    QString     playerId;              // id joueur (roster)
    QString     role = QStringLiteral("proposer");
    QJsonObject agent;                 // { cli, model, sessionId }
};

// Intention lisible (journal / tchat). Aucune valeur mécanique.
struct Intent {
    QString playerPrompt;              // texte du joueur (ou résumé)
    QString aiSummary;                 // ce que l'IA déclare vouloir, 1-3 phrases
};

// Version de base pour la détection de conflit optimiste (doc 13 §3). Un champ
// à -1 = « non renseigné » (le slice solo n'en a pas besoin ; présent dès la v1
// pour ne pas casser le format au passage collab).
struct BaseVersion {
    qint64 rulebook    = -1;
    qint64 mapRevision = -1;
    qint64 journalSeq  = -1;

    bool isSet() const { return rulebook >= 0 || mapRevision >= 0 || journalSeq >= 0; }
    QJsonObject toJson() const;
    static BaseVersion fromJson(const QJsonObject &o);
};

// Une opération du lot atomique (doc 13 §3). Les champs saillants pour le P0
// (classification, write-set, dédup) sont extraits ; l'objet brut est conservé
// pour le round-trip et l'application aval.
struct Operation {
    QString     op;                    // editor_place, memory_set, editor_edit, roster_edit, module_config…
    QString     kind;                  // zone, case, asset, npc… (editor_place)
    QString     subop;                 // move/resize/delete/link (editor_edit)
    QString     scope;                 // tile/session/player (memory_set)
    QString     uuid;                  // cible (memory_set, editor_edit)
    QString     key;                   // clé mémoire (memory_set)
    QString     clientOpId;            // dédup idempotente au rejeu réseau (Q-F06)
    QJsonObject raw;                   // objet complet d'origine

    // Catégorie mécanique de CETTE opération (composante du max d'enveloppe).
    RequestType category() const;
    // Entrées de write-set déduites de l'opération ("<uuid>/<key>"…). Best-effort.
    QStringList writeSet() const;

    static Operation fromJson(const QJsonObject &o);
    QJsonObject toJson() const;
};

// Un artefact QML/JS embarqué (doc 13 §3). Rend l'enveloppe `code`.
struct Artifact {
    QString     contentHash;           // sha256:…
    QString     source;                // QML/JS inline (≤ 20 KB)
    QString     targetUuid;            // tuile porteuse (optionnel)
    QString     executionPolicy = QStringLiteral("host_only"); // | replicated_revalidated
    QStringList declaredWriteSet;      // "<uuid>/state/score"…
    QStringList listensTo;             // zoneEntered, memory:<uuid>/config/owner…
    QStringList requiresModules;       // dépendances vers modules gameplay (D41)

    static Artifact fromJson(const QJsonObject &o);
    QJsonObject toJson() const;
};

// L'enveloppe complète.
struct Envelope {
    int         envelopeVersion = kEnvelopeVersion;
    QString     proposalId;            // uuid (généré si absent)
    QString     channelVersion;        // ex. "1.0.0"

    Author      author;
    Intent      intent;
    BaseVersion baseVersion;

    QList<Operation> operations;
    QList<Artifact>  artifacts;

    // Note : le `requestType` et le `writeSet` DÉCLARÉS dans le JOSN d'entrée
    // sont IGNORÉS — recalculés par computeRequestType()/computeWriteSet(). On
    // ne les stocke donc pas comme champs.

    QString     createdAt;             // ISO-8601
    QString     expiresAt;             // ISO-8601 (optionnel, non appliqué au slice, doc 13 §10)

    // --- P0 : calculs mécaniques faisant foi (doc 13 §3) ---
    // requestType = MAX des catégories des opérations et artefacts (un artefact
    // ⇒ code, quoi qu'en dise l'auteur).
    RequestType computeRequestType() const;
    // writeSet global = union des write-sets des opérations et des
    // declaredWriteSet des artefacts (trié, dédupliqué).
    QStringList computeWriteSet() const;
    // Union des modules requis par les artefacts (vérif `requiresModules`, D41).
    QStringList requiredModules() const;

    // --- Parsing / sérialisation ---
    // `error` renseigné (et retour `false`) si le JSON est structurellement
    // invalide : version non supportée, > kMaxOps/kMaxArtifacts, source d'artefact
    // > kMaxArtifactBytes. Le contenu métier (validité des ops) est vérifié plus
    // tard par le P0 applicatif — ici c'est la seule validation de FORME.
    static bool fromJson(const QJsonObject &o, Envelope &out, QString &error);
    // Round-trip : réémet le requestType/writeSet CALCULÉS (jamais les déclarés)
    // pour que le journal reflète la vue de l'hôte.
    QJsonObject toJson() const;
};

} // namespace meow::proposal

#endif // MEOW_PROPOSAL_ENVELOPE_H
