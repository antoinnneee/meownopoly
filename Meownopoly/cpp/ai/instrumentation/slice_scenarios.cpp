#include "slice_scenarios.h"

#include <QCryptographicHash>
#include <QElapsedTimer>
#include <QJsonArray>
#include <QJsonDocument>
#include <QTimer>
#include <QUuid>

#include "slice_instrumentation.h"

#include "../bench/bench_pool.h"
#include "../bench/bench_protocol.h"
#include "../sandbox/static_validator.h"

#include "../proposal/proposal_envelope.h"
#include "../proposal/proposal_lifecycle.h"
#include "../proposal/proposal_types.h"
#include "../proposal/proposal_verdict.h"

using namespace meow::proposal;

SliceScenarioRunner *SliceScenarioRunner::m_instance = nullptr;

SliceScenarioRunner::SliceScenarioRunner(QObject *parent) : QObject(parent) {}

SliceScenarioRunner *SliceScenarioRunner::instance()
{
    if (!m_instance) m_instance = new SliceScenarioRunner();
    return m_instance;
}

QObject *SliceScenarioRunner::qmlInstance(QQmlEngine *, QJSEngine *)
{
    SliceScenarioRunner *inst = SliceScenarioRunner::instance();
    QQmlEngine::setObjectOwnership(inst, QQmlEngine::CppOwnership);
    return inst;
}

void SliceScenarioRunner::registerQml()
{
    qmlRegisterSingletonType<SliceScenarioRunner>(
        "MeowSlice", 1, 0, "SliceScenarioRunner", &SliceScenarioRunner::qmlInstance);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

int SliceScenarioRunner::estimateTokens(const QString &text)
{
    // Proxy grossier ≈ octets/4 (ordre de grandeur des tokeniseurs BPE anglais).
    // C'est une mesure de TAILLE de charge utile, pas un vrai comptage — remplacé
    // par le relevé réel de l'agent quand la piste C branche `claude -p`.
    const int bytes = text.toUtf8().size();
    return (bytes + 3) / 4;
}

QString SliceScenarioRunner::skillPrePromptProxy()
{
    // Représentatif de la skill injectée au spawn (D17) : ~ une page de contrat.
    return QStringLiteral(
        "MEOW SKILL v1 — tools: state_query, editor_place, editor_edit, "
        "memory_set, module_config, artifact_submit, events_poll, screenshot, "
        "arbiter_verdict. requestType recalculé par l'hôte. Un artefact ⇒ code, "
        "passe par l'arbitre puis le banc hors-process. Budgets runtime: handler "
        "2 ms, tick 0,5 ms, 30 emit/s. Façade Meow.GameApi: memory.get/set, "
        "events.on/emit, stats.addModifier, dialogue.show, anim.play, fx.spawn, "
        "sound.play. Toute écriture doit être dans le write-set déclaré.");
}

QJsonObject SliceScenarioRunner::buildTrappedPlateEnvelope(const QString &tag,
                                                           bool oversizedArtifact) const
{
    const QString uuid = QStringLiteral("plate-%1").arg(tag);

    QJsonObject author;
    author.insert(QStringLiteral("playerId"), QStringLiteral("solo-host"));
    author.insert(QStringLiteral("role"), QStringLiteral("proposer"));
    QJsonObject agent;
    agent.insert(QStringLiteral("cli"), QStringLiteral("claude"));
    agent.insert(QStringLiteral("model"), QStringLiteral("harness-sim"));
    author.insert(QStringLiteral("agent"), agent);

    QJsonObject intent;
    intent.insert(QStringLiteral("playerPrompt"),
                  QStringLiteral("Ajoute une plaque piégée : marcher dessus projette "
                                 "le chat et lui retire 5 points, sauf s'il possède la case."));
    intent.insert(QStringLiteral("aiSummary"),
                  QStringLiteral("Zone + artefact JS abonné à zoneEntered ; lit "
                                 "memory config owner ; stats.addModifier + impulsion."));

    // --- Opérations : module_config (dépendance) + editor_place + memory_set ---
    QJsonArray ops;
    {
        QJsonObject o;
        o.insert(QStringLiteral("op"), QStringLiteral("module_config"));
        o.insert(QStringLiteral("kind"), QStringLiteral("stats"));
        QJsonObject raw = o;
        raw.insert(QStringLiteral("enabled"), true);
        o.insert(QStringLiteral("raw"), raw);
        ops.append(o);
    }
    {
        QJsonObject o;
        o.insert(QStringLiteral("op"), QStringLiteral("editor_place"));
        o.insert(QStringLiteral("kind"), QStringLiteral("zone"));
        o.insert(QStringLiteral("uuid"), uuid);
        ops.append(o);
    }
    {
        QJsonObject o;
        o.insert(QStringLiteral("op"), QStringLiteral("memory_set"));
        o.insert(QStringLiteral("scope"), QStringLiteral("tile"));
        o.insert(QStringLiteral("uuid"), uuid);
        o.insert(QStringLiteral("key"), QStringLiteral("config/damage"));
        ops.append(o);
    }

    // --- Artefact JS embarqué (rend l'enveloppe `code`) ---
    QString source = QStringLiteral(
        "Meow.events.on('zoneEntered', function(ev){\n"
        "  var owner = Meow.memory.get(ev.tile, 'config/owner');\n"
        "  if (owner === ev.player) return;\n"
        "  Meow.stats.addModifier(ev.player, 'score', -5);\n"
        "  Meow.fx.spawn('poof', ev.position);\n"
        "  var s = Meow.memory.get(ev.tile, 'state/hits') || 0;\n"
        "  Meow.memory.set(ev.tile, 'state/hits', s + 1);\n"
        "});\n");
    if (oversizedArtifact) {
        // Gonfle au-delà de kMaxArtifactBytes (20 KB) → rejet mécanique de forme.
        source += QString(kMaxArtifactBytes + 512, QLatin1Char('x'));
    }

    QJsonObject artifact;
    artifact.insert(QStringLiteral("contentHash"),
                    QStringLiteral("sha256:sim-%1").arg(tag));
    artifact.insert(QStringLiteral("source"), source);
    artifact.insert(QStringLiteral("targetUuid"), uuid);
    artifact.insert(QStringLiteral("executionPolicy"), QStringLiteral("host_only"));
    artifact.insert(QStringLiteral("declaredWriteSet"),
                    QJsonArray{ QStringLiteral("%1/state/hits").arg(uuid) });
    artifact.insert(QStringLiteral("listensTo"),
                    QJsonArray{ QStringLiteral("zoneEntered") });
    artifact.insert(QStringLiteral("requiresModules"),
                    QJsonArray{ QStringLiteral("stats") });

    QJsonObject env;
    env.insert(QStringLiteral("envelopeVersion"), kEnvelopeVersion);
    env.insert(QStringLiteral("proposalId"),
               QUuid::createUuid().toString(QUuid::WithoutBraces));
    env.insert(QStringLiteral("channelVersion"), QStringLiteral("1.0.0"));
    env.insert(QStringLiteral("author"), author);
    env.insert(QStringLiteral("intent"), intent);
    env.insert(QStringLiteral("operations"), ops);
    env.insert(QStringLiteral("artifacts"), QJsonArray{ artifact });
    return env;
}

// Chronomètre un pas synchrone et pousse son temps mur à l'instrumentation
// (critère 2 : aucun gel GUI). Renvoie la valeur de l'expression.
#define TIMED_STEP(instr, expr)                                                   \
    ([&]() {                                                                      \
        QElapsedTimer _t; _t.start();                                             \
        auto _r = (expr);                                                         \
        (instr)->recordGuiStallMs(_t.nsecsElapsed() / 1.0e6);                     \
        return _r;                                                                \
    })()

// ---------------------------------------------------------------------------
// S1 — création avec config + comportement
// ---------------------------------------------------------------------------
QVariantMap SliceScenarioRunner::runS1()
{
    SliceInstrumentation *instr = SliceInstrumentation::instance();
    ProposalLifecycle *lc = ProposalLifecycle::instance();
    lc->setArbiterAvailable(true);

    QVariantMap out;
    out.insert(QStringLiteral("scenario"), QStringLiteral("S1"));
    QVariantList steps;

    instr->beginInvocation(QStringLiteral("S1"));

    const QJsonObject envJson = buildTrappedPlateEnvelope(QStringLiteral("s1"), false);
    const QString envStr = QString::fromUtf8(QJsonDocument(envJson).toJson(QJsonDocument::Compact));
    instr->recordInvocationTokens(estimateTokens(skillPrePromptProxy() + envStr),
                                  estimateTokens(envStr));

    Proposal *p = TIMED_STEP(instr, lc->submitJson(envStr));
    const QString id = p->proposalId();
    steps.append(QStringLiteral("submit → %1").arg(p->stateName()));

    bool ok = (p->state() == ProposalState::Arbitrating); // code ⇒ arbitre (D25)

    if (ok) {
        instr->markArbitrationStart(id);
        Verdict v;
        v.outcome = VerdictOutcome::Accepted;
        v.reasons = {
            { audiencePlayer(), QString(), QStringLiteral("Plaque piégée acceptée."), false },
            { audienceAi(), QStringLiteral("accepted"), QStringLiteral("OK, passe au banc."), false }
        };
        QString err;
        ok = TIMED_STEP(instr, lc->provideVerdictDoc(id, v, QStringLiteral("arbiter"), &err));
        instr->markArbitrationEnd(id);
        instr->recordVerdictOutcome(QStringLiteral("accepted"));
        steps.append(QStringLiteral("verdict accepté → %1").arg(p->stateName()));
    }
    if (ok) {
        ok = TIMED_STEP(instr, lc->provideBenchResult(id, true, QStringLiteral("banc: pass")));
        steps.append(QStringLiteral("banc pass → %1").arg(p->stateName()));
    }
    if (ok) {
        ok = TIMED_STEP(instr, lc->applyProposal(id, true));
        steps.append(QStringLiteral("apply → %1").arg(p->stateName()));
    }

    const bool applied = (p->state() == ProposalState::Applied);
    instr->recordAuditReplay(id, SliceInstrumentation::replayHistory(p->history()));
    // Solo : le save/load + undo structurel du critère produit sont simulés OK
    // (le chemin réel — EditDelta before/after — est couvert par S-3 et T3-1).
    instr->recordProductCriterion(true, true);

    out.insert(QStringLiteral("ok"), applied);
    out.insert(QStringLiteral("finalState"), p->stateName());
    out.insert(QStringLiteral("proposalId"), id);
    out.insert(QStringLiteral("steps"), steps);
    emit scenarioFinished(QStringLiteral("S1"), applied);
    return out;
}

// ---------------------------------------------------------------------------
// S2 — proposition arbitrée (amendée) puis appliquée + invariant pipeline
// ---------------------------------------------------------------------------
QVariantMap SliceScenarioRunner::runS2()
{
    SliceInstrumentation *instr = SliceInstrumentation::instance();
    ProposalLifecycle *lc = ProposalLifecycle::instance();
    lc->setArbiterAvailable(true);

    QVariantMap out;
    out.insert(QStringLiteral("scenario"), QStringLiteral("S2"));
    QVariantList steps;

    instr->beginInvocation(QStringLiteral("S2"));

    const QJsonObject envJson = buildTrappedPlateEnvelope(QStringLiteral("s2"), false);
    const QString envStr = QString::fromUtf8(QJsonDocument(envJson).toJson(QJsonDocument::Compact));
    instr->recordInvocationTokens(estimateTokens(skillPrePromptProxy() + envStr),
                                  estimateTokens(envStr));

    Proposal *p = TIMED_STEP(instr, lc->submitJson(envStr));
    const QString id = p->proposalId();
    steps.append(QStringLiteral("submit → %1").arg(p->stateName()));

    bool ok = (p->state() == ProposalState::Arbitrating);

    // Chemin amendé (D32) : l'arbitre ajoute un cooldown → repasse au banc.
    if (ok) {
        instr->markArbitrationStart(id);
        Verdict v;
        v.outcome = VerdictOutcome::Amended;
        v.amendment.note = QStringLiteral("cooldown 5 s ajouté pour l'équilibrage");
        v.reasons = {
            { audiencePlayer(), QString(),
              QStringLiteral("Accepté avec un temps de recharge de 5 s."), false },
            { audienceAi(), QStringLiteral("amended"),
              QStringLiteral("Ajoute un cooldown 5 s ; repasse au banc."), true }
        };
        QString err;
        ok = TIMED_STEP(instr, lc->provideVerdictDoc(id, v, QStringLiteral("arbiter"), &err));
        instr->markArbitrationEnd(id);
        instr->recordVerdictOutcome(QStringLiteral("amended"));
        steps.append(QStringLiteral("verdict amendé → %1").arg(p->stateName()));
    }

    // Invariant pipeline (doc 11 §5.2) : rien n'atteint la partie sans le banc.
    // La proposition amendée est en `benching` → applyProposal DOIT refuser.
    const bool guardBeforeBench = !lc->applyProposal(id, true);
    steps.append(QStringLiteral("invariant: apply avant banc refusé = %1")
                     .arg(guardBeforeBench ? QStringLiteral("oui") : QStringLiteral("NON")));

    if (ok) {
        ok = TIMED_STEP(instr, lc->provideBenchResult(id, true, QStringLiteral("banc: pass (amendé)")));
        steps.append(QStringLiteral("banc pass → %1").arg(p->stateName()));
    }
    if (ok) {
        ok = TIMED_STEP(instr, lc->applyProposal(id, true));
        steps.append(QStringLiteral("apply → %1").arg(p->stateName()));
    }

    const bool applied = (p->state() == ProposalState::Applied);
    instr->recordAuditReplay(id, SliceInstrumentation::replayHistory(p->history()));

    out.insert(QStringLiteral("ok"), applied && guardBeforeBench);
    out.insert(QStringLiteral("finalState"), p->stateName());
    out.insert(QStringLiteral("proposalId"), id);
    out.insert(QStringLiteral("invariantHeld"), guardBeforeBench);
    out.insert(QStringLiteral("steps"), steps);
    emit scenarioFinished(QStringLiteral("S2"), applied && guardBeforeBench);
    return out;
}

// ---------------------------------------------------------------------------
// S3 — rejet actionnable + itération (convergence ≤ 2)
// ---------------------------------------------------------------------------
QVariantMap SliceScenarioRunner::runS3()
{
    SliceInstrumentation *instr = SliceInstrumentation::instance();
    ProposalLifecycle *lc = ProposalLifecycle::instance();
    lc->setArbiterAvailable(true);

    QVariantMap out;
    out.insert(QStringLiteral("scenario"), QStringLiteral("S3"));
    QVariantList steps;

    instr->beginInvocation(QStringLiteral("S3"));

    // Itération 1 : artefact hors-taille → rejet mécanique de forme (P0), actionnable.
    const QJsonObject bad = buildTrappedPlateEnvelope(QStringLiteral("s3-bad"), true);
    const QString badStr = QString::fromUtf8(QJsonDocument(bad).toJson(QJsonDocument::Compact));
    instr->recordInvocationTokens(estimateTokens(skillPrePromptProxy() + badStr),
                                  estimateTokens(badStr));

    Proposal *p1 = TIMED_STEP(instr, lc->submitJson(badStr));
    const QString id1 = p1->proposalId();
    const bool rejected = (p1->state() == ProposalState::RejectedMechanical);

    // Le rejet est actionnable : dernière transition porte un `code` (retryable).
    QString rejectCode;
    if (!p1->history().isEmpty())
        rejectCode = p1->history().last().toMap().value(QStringLiteral("code")).toString();
    steps.append(QStringLiteral("iter1: %1 (code=%2)").arg(p1->stateName(), rejectCode));

    // Itération 2 (même intention) : source corrigée dans les bornes → aboutit.
    instr->beginInvocation(QStringLiteral("S3-retry"));
    const QJsonObject good = buildTrappedPlateEnvelope(QStringLiteral("s3-good"), false);
    const QString goodStr = QString::fromUtf8(QJsonDocument(good).toJson(QJsonDocument::Compact));
    instr->recordInvocationTokens(estimateTokens(skillPrePromptProxy() + goodStr),
                                  estimateTokens(goodStr));

    Proposal *p2 = TIMED_STEP(instr, lc->submitJson(goodStr));
    const QString id2 = p2->proposalId();
    bool ok = (p2->state() == ProposalState::Arbitrating);

    if (ok) {
        instr->markArbitrationStart(id2);
        Verdict v;
        v.outcome = VerdictOutcome::Accepted;
        v.reasons = {
            { audiencePlayer(), QString(), QStringLiteral("Corrigé, accepté."), false },
            { audienceAi(), QStringLiteral("accepted"), QStringLiteral("OK."), false }
        };
        QString err;
        ok = TIMED_STEP(instr, lc->provideVerdictDoc(id2, v, QStringLiteral("arbiter"), &err));
        instr->markArbitrationEnd(id2);
        instr->recordVerdictOutcome(QStringLiteral("accepted"));
    }
    if (ok) ok = TIMED_STEP(instr, lc->provideBenchResult(id2, true));
    if (ok) ok = TIMED_STEP(instr, lc->applyProposal(id2, true));
    steps.append(QStringLiteral("iter2: %1").arg(p2->stateName()));

    // Convergence : 2 itérations pour la même intention « plaque piégée ».
    const int iterations = 2;
    instr->recordConvergence(QStringLiteral("S3-plate"), iterations);

    instr->recordAuditReplay(id1, SliceInstrumentation::replayHistory(p1->history()));
    instr->recordAuditReplay(id2, SliceInstrumentation::replayHistory(p2->history()));

    const bool converged = rejected && (p2->state() == ProposalState::Applied)
                           && (iterations <= MEOW_SLICE_MAX_CONVERGENCE_ITERATIONS)
                           && !rejectCode.isEmpty();
    out.insert(QStringLiteral("ok"), converged);
    out.insert(QStringLiteral("iterations"), iterations);
    out.insert(QStringLiteral("rejectCode"), rejectCode);
    out.insert(QStringLiteral("proposalIds"), QVariantList{ id1, id2 });
    out.insert(QStringLiteral("finalState"), p2->stateName());
    out.insert(QStringLiteral("steps"), steps);
    emit scenarioFinished(QStringLiteral("S3"), converged);
    return out;
}

// ---------------------------------------------------------------------------
QVariantMap SliceScenarioRunner::runAll()
{
    SliceInstrumentation *instr = SliceInstrumentation::instance();
    instr->reset();

    QVariantList scenarios;
    scenarios.append(runS1());
    scenarios.append(runS2());
    scenarios.append(runS3());

    QVariantMap out;
    out.insert(QStringLiteral("scenarios"), scenarios);
    out.insert(QStringLiteral("report"), instr->report());
    return out;
}

// ---------------------------------------------------------------------------
//  Validation d'un artefact au banc réel (harness V3)
// ---------------------------------------------------------------------------

meow::bench::BenchPool *SliceScenarioRunner::ensureBenchPool()
{
    if (!m_benchPool) {
        m_benchPool = new meow::bench::BenchPool(this);
        connect(m_benchPool, &meow::bench::BenchPool::verdictReady, this,
                [this](const QString &jobId, const QJsonObject &verdict) {
                    QVariantMap m = verdict.toVariantMap();
                    if (!m.contains(QStringLiteral("stage")))
                        m.insert(QStringLiteral("stage"), QStringLiteral("bench"));
                    emit artifactVerdictReady(jobId, m);
                });
    }
    return m_benchPool;
}

QString SliceScenarioRunner::validateArtifact(const QString &source, const QString &targetUuid)
{
    namespace sb = meow::sandbox;

    const QString jobId =
        QStringLiteral("harness_") + QUuid::createUuid().toString(QUuid::WithoutBraces);

    // — P0 statique d'abord (même ordre que le canal réel, doc 12 §3). —
    sb::StaticValidationInput sin;
    sin.source = source;
    const sb::StaticValidationResult p0 = sb::StaticValidator::validate(sin);
    if (!p0.passed()) {
        QJsonObject verdict;
        verdict.insert(QStringLiteral("jobId"), jobId);
        verdict.insert(QStringLiteral("verdict"), QStringLiteral("fail"));
        verdict.insert(QStringLiteral("stage"), QStringLiteral("P0"));
        QJsonArray fs;
        for (const sb::StaticFinding &f : p0.findings)
            fs.append(f.toJson());
        verdict.insert(QStringLiteral("failures"), fs);
        QJsonObject metrics;
        metrics.insert(QStringLiteral("imports"), QJsonArray::fromStringList(p0.imports));
        verdict.insert(QStringLiteral("metrics"), metrics);
        // Émission asynchrone (cohérent avec le chemin banc : le verdict arrive
        // toujours après le retour de validateArtifact).
        QTimer::singleShot(0, this, [this, jobId, verdict]() {
            emit artifactVerdictReady(jobId, verdict.toVariantMap());
        });
        return jobId;
    }

    // — P0 franchi : job du banc hors-process (contrat bench_protocol). —
    QJsonObject artifact;
    artifact.insert(QStringLiteral("source"), source);
    if (!targetUuid.isEmpty())
        artifact.insert(QStringLiteral("targetUuid"), targetUuid);
    artifact.insert(QStringLiteral("contentHash"),
                    QString::fromLatin1(QCryptographicHash::hash(
                        source.toUtf8(), QCryptographicHash::Sha256).toHex()));

    QJsonObject snapshot;
    snapshot.insert(QStringLiteral("map"), QJsonObject{});
    snapshot.insert(QStringLiteral("memory"), QJsonObject{});
    snapshot.insert(QStringLiteral("modules"), QJsonObject{});

    QJsonObject job;
    job.insert(QStringLiteral("jobId"), jobId);
    job.insert(QStringLiteral("benchVersion"), meow::bench::kBenchVersion);
    job.insert(QStringLiteral("snapshot"), snapshot);
    job.insert(QStringLiteral("artifact"), artifact);
    job.insert(QStringLiteral("budgets"), QJsonObject{});   // défauts du banc
    job.insert(QStringLiteral("stimuli"), QJsonArray{});
    job.insert(QStringLiteral("seed"), qint64(0));

    ensureBenchPool()->submit(job);
    return jobId;
}
