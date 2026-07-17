#ifndef MEOW_BENCH_PROTOCOL_H
#define MEOW_BENCH_PROTOCOL_H

// ============================================================================
// bench_protocol — contrat job / verdict du banc d'essai hors-process (D26)
// ============================================================================
//
// Spécification : doc/v3/12_BANC_ESSAI_R1.md §2.2 / §2.3 / §4.
//
// Ce module est le **langage commun** entre les deux extrémités du banc :
//   - l'exécutable jetable `meow_testbench` (lit le job, rend le verdict) ;
//   - le superviseur côté jeu `BenchSupervisor` (écrit le job, relit le
//     verdict, synthétise timeout/crash).
// Il ne dépend que de Qt6::Core (QJson/QString/QFile) — aucun module réseau,
// aucune brique de jeu — pour rester liable dans le banc sans surface réseau
// (doc 12 §5) comme dans le jeu.
//
// Livrable de la tâche A2 (« protocole job/verdict »). Les phases P1→P5 qui
// remplissent `metrics` et les `failures` métier arrivent avec A5 ; le
// vocabulaire des codes est figé ici dès maintenant pour stabiliser le canal
// (doc 12 §4 : les codes remontent tels quels à l'IA cliente).
// ============================================================================

#include <QString>
#include <QByteArray>
#include <QJsonObject>
#include <QJsonArray>
#include <QList>

namespace meow::bench {

// Version du protocole (doc 12 §7). Un bump invalide le cache de verdicts.
inline constexpr int kBenchVersion = 1;

// Préfixe de la ligne de verdict sur stdout (doc 12 §2.2). Le préfixe permet
// au superviseur de retrouver le verdict au milieu de logs Qt parasites.
inline constexpr char kVerdictPrefix[] = "MEOWBENCH:";

// ─── Codes d'échec stables (doc 12 §3 / §4) ─────────────────────────────────
// Documentés dans le manifeste du canal ; remontent tels quels à l'IA (S3).
namespace failure {
    // Protocole job/verdict (A2)
    inline constexpr char kJobReadError[]   = "job_read_error";
    inline constexpr char kJobParseError[]  = "job_parse_error";
    inline constexpr char kJobInvalid[]     = "job_invalid";
    inline constexpr char kNotImplemented[] = "bench_not_implemented";
    // Supervision côté jeu (A3)
    inline constexpr char kBenchTimeout[]   = "bench_timeout";
    inline constexpr char kCrash[]          = "crash";
    // Phases P1→P5 (A5) — vocabulaire figé dès A2
    inline constexpr char kSnapshotInvalid[]   = "snapshot_invalid";
    inline constexpr char kLoadFailed[]        = "load_failed";
    inline constexpr char kLoadTimeout[]       = "load_timeout";
    inline constexpr char kTickBudget[]        = "tick_budget";
    inline constexpr char kRunawayAlloc[]      = "runaway_alloc";
    inline constexpr char kEventBudget[]       = "event_budget";
    inline constexpr char kEventFlood[]        = "event_flood";
    inline constexpr char kMemoryQuota[]       = "memory_quota";
    inline constexpr char kObjectQuota[]       = "object_quota";
    inline constexpr char kLeak[]              = "leak";
    inline constexpr char kWritesetViolation[] = "writeset_violation";
} // namespace failure

// ─── Job (entrée, doc 12 §2.3) ──────────────────────────────────────────────
struct BenchJob {
    QString     jobId;
    int         benchVersion = 0;
    QJsonObject snapshot;   // { map, memory, modules }
    QJsonObject artifact;   // { source, targetUuid, contentHash, meta }
    QJsonObject budgets;    // valeurs D34 sérialisées
    QJsonArray  stimuli;    // scénarios §4
    qint64      seed = 0;

    // Résultat du parse/validation. Ne lève jamais : sur échec, `ok` reste
    // false et `errorCode` (un failure::kJob*) + `errorDetails` sont renseignés.
    bool    ok = false;
    QString errorCode;
    QString errorDetails;
};

// Lit et valide un fichier de job JSON (doc 12 §2.3). Chemin vide, illisible,
// JSON invalide ou champs obligatoires manquants → BenchJob{ok=false}.
BenchJob parseJobFile(const QString &path);

// ─── Verdict (sortie, doc 12 §4) ────────────────────────────────────────────
struct BenchFailure {
    QString     code;              // failure::k*
    QString     phase;             // "P1".."P5" ; vide si hors phase
    QString     details;           // phrase exploitable par un LLM
    bool        retryable = false;
    QJsonObject extra;             // champs additionnels (ex. exitCode d'un crash)

    QJsonObject toJson() const;
};

struct BenchVerdict {
    QString             jobId;
    int                 benchVersion = kBenchVersion;
    bool                pass = false;
    QList<BenchFailure> failures;
    QJsonObject         metrics;      // §4 — peuplé en A5
    qint64              durationMs = 0;

    QJsonObject toJson() const;

    // Raccourci : construit un verdict d'échec à un seul code.
    static BenchVerdict fail(const QString &jobId, const BenchFailure &f);
};

// Sérialise la ligne unique `MEOWBENCH:{…}` (JSON compact, sans '\n' final).
QByteArray formatVerdictLine(const QJsonObject &verdict);

// Extrait le dernier objet verdict d'un flux stdout : cherche la dernière
// ligne préfixée `MEOWBENCH:` parsable. Objet vide si aucune (→ crash présumé).
QJsonObject extractVerdict(const QByteArray &stdoutData);

// Verdicts synthétiques rendus par le superviseur (doc 12 §2.2).
QJsonObject makeTimeoutVerdict(const QString &jobId, int timeoutMs);
QJsonObject makeCrashVerdict(const QString &jobId, int exitCode, const QString &details = QString());

} // namespace meow::bench

#endif // MEOW_BENCH_PROTOCOL_H
