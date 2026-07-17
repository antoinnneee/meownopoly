/*
 *      V3 / Phase 2 — S-2 · Retour MCP du pivot de proposition (doc v3 13 §5)
 *
 * Façade appelée par les tools MCP `artifact_submit` (et le futur lot d'ops).
 * Encapsule le comportement de RETOUR au proposant :
 *
 *   - Mode BLOQUANT par défaut : `artifactSubmit` ne rend la main qu'au verdict
 *     (accepté/rejeté/amendé) ou à un rejet mécanique — jamais au-delà de
 *     `MEOW_PROPOSAL_TIMEOUT_MS` (60 s).
 *   - Au TIMEOUT : réponse `{ status: "pending", proposalId }` — l'IA continue,
 *     le verdict arrivera dans le résumé d'événements du tour suivant et reste
 *     lisible via `events_poll` / `state_query`.
 *   - Le verdict rendu porte `reasons[audience=ai]` (code + consigne actionnable
 *     + retryable) et, si amendé, le diff résumé (doc 13 §5).
 *
 * L'attente bloquante est un `QEventLoop` imbriqué sur le thread GUI : la
 * passerelle MCP (piste C, `QtHttpServer`) dispatche déjà ses appels de tool sur
 * ce thread. La façade ne fait AUCUN réseau ; elle s'appuie sur
 * ProposalLifecycle (rôle hôte, P0 fait foi).
 *
 * Périmètre S-2 : ce fichier + le document de verdict (proposal_verdict) + le
 * point d'entrée arbitre de la machine (ProposalLifecycle::provideVerdictDoc).
 * L'enregistrement dans la scène QML et le branchement sur les tools MCP réels
 * (`AiGatewayServer`) sont piste C — registerQml() existe mais n'est pas encore
 * câblé (comme S-1).
 */
#ifndef MEOW_PROPOSAL_GATEWAY_H
#define MEOW_PROPOSAL_GATEWAY_H

#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QVariantMap>

class Proposal;

// ---------------------------------------------------------------------------
// ProposalGateway — retour MCP bloquant/pending du pivot de proposition.
// ---------------------------------------------------------------------------
class ProposalGateway : public QObject
{
    Q_OBJECT
    // Délai d'attente bloquante appliqué (ms) — expose la constante
    // MEOW_PROPOSAL_TIMEOUT_MS pour l'UI / les tests.
    Q_PROPERTY(int timeoutMs READ timeoutMs CONSTANT)

public:
    static void registerQml();
    static ProposalGateway *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    int timeoutMs() const;

    // Tool MCP `artifact_submit` (doc 13 §5). Soumet l'enveloppe à
    // ProposalLifecycle puis ATTEND (bloquant, nested event loop) le verdict de
    // l'arbitre ou un rejet mécanique, dans la limite de `timeoutMs`.
    //   - décidé   : { status: "decided", proposalId, verdict, reason{code,text,
    //                  retryable}, amendment?, benchReport? }
    //   - mécanique : idem status "decided", verdict "rejected", reason synthé-
    //                  tisée depuis le code du préfiltre P0 (retryable selon code)
    //   - timeout   : { status: "pending", proposalId }
    Q_INVOKABLE QVariantMap artifactSubmit(const QVariantMap &envelopeJson);

    // Variante depuis une chaîne JSON brute (confort tests / MCP).
    Q_INVOKABLE QVariantMap artifactSubmitJson(const QString &json);

private:
    explicit ProposalGateway(QObject *parent = nullptr);
    static ProposalGateway *m_instance;

    // Vrai si la proposition a un résultat consommable par le tool : un verdict
    // d'arbitre attaché, OU un état terminal (rejet mécanique, application…).
    static bool hasOutcome(const Proposal *p);
    // Construit le retour MCP « décidé » : verdict complet s'il existe, sinon
    // synthèse depuis la dernière transition (rejet mécanique / banc / échec).
    static QVariantMap buildDecidedReturn(const Proposal *p);
};

#endif // MEOW_PROPOSAL_GATEWAY_H
