/*
 *      V3 / Phase 2 — S-7 · Scénarios du vertical slice S1/S2/S3 (doc v3 11 §3)
 *
 * Harness qui DÉROULE les trois scénarios end-to-end du slice solo contre le
 * pivot de proposition (ProposalLifecycle, rôle hôte, P0 fait foi) et alimente
 * SliceInstrumentation pour vérifier les critères doc 11 §5.
 *
 * Il joue les DEUX rôles IA (D6/D9 : « un joueur = les deux rôles quand même ») :
 *   - le proposant  : construit l'enveloppe « plaque piégée » (doc 11 §2) et la
 *                     soumet ;
 *   - l'arbitre     : rend le verdict (accepté / amendé / rejeté) ;
 *   - le banc       : rend un pass/fail (SANS exécuter l'artefact in-process — le
 *                     vrai banc est hors-process D26 ; le harness simule son issue
 *                     pour prouver le CÂBLAGE du pipeline et l'absence de gel GUI).
 *
 * Chaque pas synchrone est chronométré (temps mur → recordGuiStallMs) pour le
 * critère 2. L'audit (journal D19) de chaque proposition est rejoué (critère 3).
 * Les tokens sont relevés en proxy de taille de charge utile tant qu'aucun agent
 * réel n'est branché (critère 4, piste C).
 *
 * S1 — création (config + comportement) : enveloppe complète, arbitre accepte,
 *      banc pass, application. La proposition atteint `applied`.
 * S2 — arbitrage puis application : chemin AMENDÉ (D32, repasse au banc) +
 *      preuve d'invariant « rien n'atteint la partie sans arbitre+banc » (une
 *      proposition non validée refuse `applyProposal`). Mesure la latence.
 * S3 — rejet actionnable + itération : 1re soumission fautive (artefact hors
 *      taille → rejet mécanique P0, retryable) ; 2e soumission corrigée aboutit.
 *      Convergence = 2 (critère ≤ 2).
 *
 * Usable headless via `instance()` (C++) ; enregistrable QML sur `MeowSlice`.
 */
#ifndef MEOW_SLICE_SCENARIOS_H
#define MEOW_SLICE_SCENARIOS_H

#include <QJsonObject>
#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QVariantMap>

namespace meow::bench { class BenchPool; }

class SliceScenarioRunner : public QObject
{
    Q_OBJECT

public:
    static void registerQml();
    static SliceScenarioRunner *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    // Déroule un scénario ; renvoie son résultat structuré ({ scenario, ok,
    // steps, proposalIds, note }). N'agit PAS sur reset() de l'instrumentation
    // (permet de chaîner) — sauf runAll().
    Q_INVOKABLE QVariantMap runS1();
    Q_INVOKABLE QVariantMap runS2();
    Q_INVOKABLE QVariantMap runS3();

    // reset() de l'instrumentation puis S1 → S2 → S3. Renvoie
    // { scenarios: [...], report: <SliceInstrumentation::report()> }.
    Q_INVOKABLE QVariantMap runAll();

    // ── Validation d'un artefact au banc réel (harness V3) ──────────────────
    // Wrapper QML autour du pipeline « P0 statique puis banc hors-process »
    // (même ordre que le canal réel, cf. AiGatewayServer::toolArtifactDryrun).
    // 100 % asynchrone : rend un jobId aussitôt, le verdict arrive par le signal
    // `artifactVerdictReady(jobId, verdict)`. Un échec P0 rend un verdict
    // synthétique (stage "P0") sans spawner de process. `verdict` porte
    // { verdict: "pass"|"fail", failures: [...], metrics: {...}, stage }.
    Q_INVOKABLE QString validateArtifact(const QString &source,
                                         const QString &targetUuid = QString());

signals:
    void scenarioFinished(const QString &scenario, bool ok);
    // Verdict d'un artefact soumis via validateArtifact (corrélé par jobId).
    void artifactVerdictReady(const QString &jobId, const QVariantMap &verdict);

private:
    explicit SliceScenarioRunner(QObject *parent = nullptr);
    static SliceScenarioRunner *m_instance;

    // Pool de banc partagé (lazy) pour validateArtifact. Un slot au MVP.
    meow::bench::BenchPool *ensureBenchPool();
    meow::bench::BenchPool *m_benchPool = nullptr;

    // Construit l'enveloppe « plaque piégée » (doc 11 §2). `oversizedArtifact`
    // gonfle la source de l'artefact au-delà de kMaxArtifactBytes pour provoquer
    // un rejet mécanique de FORME (P0). `tag` distingue les itérations.
    QJsonObject buildTrappedPlateEnvelope(const QString &tag, bool oversizedArtifact) const;

    // Proxy de comptage de tokens (≈ octets/4) tant qu'aucun agent réel n'est
    // branché (piste C). Documenté comme mesure de taille de charge, pas de coût.
    static int estimateTokens(const QString &text);

    // Pré-prompt skill approximé (taille représentative pour le proxy tokens).
    static QString skillPrePromptProxy();
};

#endif // MEOW_SLICE_SCENARIOS_H
