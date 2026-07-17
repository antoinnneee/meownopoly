/*
 *      V3 / Phase 2 — S-7 · Instrumentation du vertical slice (doc v3 11 §5)
 *
 * Collecteur de mesures des CRITÈRES D'ACCEPTATION du slice solo (doc 11 §5) et
 * des indicateurs Q-J04. Il ne PILOTE rien : les scénarios S1/S2/S3
 * (slice_scenarios) et — à terme — le vrai canal MCP l'alimentent via des points
 * d'enregistrement, puis `report()` synthétise le verdict.
 *
 * Les 5 critères doc 11 §5 :
 *   1. Aucun accès hors canal   → compteur d'accès hors canal (AutomationServer,
 *      singletons masqués…). Toute incrémentation = échec du critère.
 *   2. Aucun gel GUI            → temps mur max d'un pas synchrone sur le thread
 *      GUI (le banc est hors-process, D26 — un artefact pathologique meurt AU
 *      banc, jamais in-process). Budget `MEOW_SLICE_GUI_STALL_BUDGET_MS`.
 *   3. Audit complet rejouable  → part des propositions dont le journal (D19) se
 *      rejoue sans trou (seq monotone, arêtes légales du graphe d'états).
 *   4. Économie mesurée         → tokens relevés par invocation (Q-E08 / doc 02
 *      §3). Au MVP, proxy = taille des charges utiles (schéma + pré-prompt +
 *      enveloppe) tant qu'aucun agent réel n'est branché (piste C).
 *   5. Critère produit D9       → la plaque piégée survit save/load, undo propre.
 *
 * Q-J04 (indicateurs d'exploitation) : latence d'arbitrage p50/p95/max, taux
 * accept/amend/reject, itérations de convergence sur échec mécanique (≤ 2, S3).
 *
 * Singleton : usable en C++ dès `instance()` (le harness s'en sert headless) et
 * enregistrable QML sur le module `MeowSlice` (registerQml() existe, câblage
 * qmlapp.cpp hors périmètre S-7 — cf. blockers).
 */
#ifndef MEOW_SLICE_INSTRUMENTATION_H
#define MEOW_SLICE_INSTRUMENTATION_H

#include <QHash>
#include <QList>
#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

// --- Budgets / seuils, surclassables à la compilation (bancs / tests) ---

// Budget de gel GUI (ms) : un pas synchrone du pipeline au-delà = critère 2 raté.
// Généreux au MVP (le seul travail synchrone est la machine à états, µs) — le
// vrai calcul lourd (banc) est hors-process.
#ifndef MEOW_SLICE_GUI_STALL_BUDGET_MS
#define MEOW_SLICE_GUI_STALL_BUDGET_MS 100.0
#endif

// Convergence max tolérée sur un échec mécanique (S3, doc 11 §5).
#ifndef MEOW_SLICE_MAX_CONVERGENCE_ITERATIONS
#define MEOW_SLICE_MAX_CONVERGENCE_ITERATIONS 2
#endif

class SliceInstrumentation : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int invocationCount READ invocationCount NOTIFY reportChanged)
    Q_PROPERTY(double maxGuiStallMs READ maxGuiStallMs NOTIFY reportChanged)
    Q_PROPERTY(int offChannelAccessCount READ offChannelAccessCount NOTIFY reportChanged)
    Q_PROPERTY(bool overallPass READ overallPass NOTIFY reportChanged)

public:
    static void registerQml();
    static SliceInstrumentation *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    // Remet tous les compteurs à zéro (début d'une campagne S1/S2/S3).
    Q_INVOKABLE void reset();

    // --- Économie / invocations (critère 4) ---
    // Ouvre une invocation logique (un tour de l'IA). Retourne son index.
    Q_INVOKABLE int  beginInvocation(const QString &intentId);
    // Tokens relevés pour la DERNIÈRE invocation ouverte (proxy taille au MVP).
    Q_INVOKABLE void recordInvocationTokens(int promptTokens, int completionTokens);

    // --- Q-J04 : arbitrage ---
    Q_INVOKABLE void markArbitrationStart(const QString &proposalId);
    // Clôt la fenêtre d'arbitrage ouverte pour `proposalId` et pousse la latence.
    Q_INVOKABLE void markArbitrationEnd(const QString &proposalId);
    // Compte l'issue d'arbitrage : "accepted" | "amended" | "rejected".
    Q_INVOKABLE void recordVerdictOutcome(const QString &outcome);

    // --- S3 : convergence (critère ≤ 2 itérations) ---
    Q_INVOKABLE void recordConvergence(const QString &intentId, int iterations);

    // --- Critère 1 : accès hors canal (toute incrémentation = échec) ---
    Q_INVOKABLE void recordOffChannelAccess(const QString &what = QString());

    // --- Critère 2 : gel GUI (temps mur d'un pas synchrone) ---
    Q_INVOKABLE void recordGuiStallMs(double ms);

    // --- Critère 3 : audit rejouable ---
    Q_INVOKABLE void recordAuditReplay(const QString &proposalId, bool ok);
    // Rejoue un journal de transitions (liste {from,to,seq,…}) et vérifie
    // seq monotone + chaque arête légale du graphe d'états (doc 13 §2). Statique,
    // sans état — utilisable par le harness comme par QML.
    Q_INVOKABLE static bool replayHistory(const QVariantList &history);

    // --- Critère 5 : produit D9 (save/load + undo propre) ---
    Q_INVOKABLE void recordProductCriterion(bool savedLoadedOk, bool undoCleanOk);

    // --- Lecture ---
    int    invocationCount() const { return m_invocations.size(); }
    double maxGuiStallMs() const   { return m_maxGuiStallMs; }
    int    offChannelAccessCount() const { return m_offChannelAccessCount; }
    bool   overallPass() const;

    // Rapport complet (doc 11 §5 + Q-J04) : critères + indicateurs + verdict.
    Q_INVOKABLE QVariantMap report() const;

    // Percentile linéaire (p ∈ [0,1]) sur un échantillon (copie triée en interne).
    static double percentile(QList<double> samples, double p);

signals:
    void reportChanged();
    // Émis à chaque accès hors canal (critère 1) — hook UI/alerte.
    void offChannelAccessDetected(const QString &what);

private:
    explicit SliceInstrumentation(QObject *parent = nullptr);
    static SliceInstrumentation *m_instance;

    struct Invocation {
        QString intentId;
        int     promptTokens = 0;
        int     completionTokens = 0;
        bool    tokensMeasured = false;
    };

    QList<Invocation>        m_invocations;
    QHash<QString, qint64>   m_arbStart;      // proposalId → t0 (ms epoch)
    QList<double>            m_arbLatenciesMs;
    int                      m_accepted = 0;
    int                      m_amended = 0;
    int                      m_rejected = 0;
    QVariantList             m_convergence;   // { intentId, iterations, pass }
    int                      m_maxConvergence = 0;
    int                      m_offChannelAccessCount = 0;
    double                   m_maxGuiStallMs = 0.0;
    int                      m_auditTotal = 0;
    int                      m_auditOk = 0;
    // Critère 5 : agrégé (ET) sur toutes les instances enregistrées.
    bool                     m_productSeen = false;
    bool                     m_savedLoadedOk = true;
    bool                     m_undoCleanOk = true;
};

#endif // MEOW_SLICE_INSTRUMENTATION_H
