#ifndef BENCH_VERDICT_H
#define BENCH_VERDICT_H

// ============================================================================
// Construction et émission du verdict du banc (doc/v3/12_BANC_ESSAI_R1.md §4).
// Une seule ligne sur stdout, préfixée MEOWBENCH:, exit code 0 dès qu'un
// verdict est rendu (quel qu'il soit).
// ============================================================================

#include <QJsonObject>
#include <QList>
#include <QString>

struct BenchFailure
{
    QString code;    // stable, documenté dans le manifeste du canal
    QString phase;   // "job", "P1".."P5", "watchdog"
    QString details; // phrase exploitable par un LLM
    bool retryable = false;
};

// Écrit la ligne `MEOWBENCH:{...}` sur stdout et flush. Thread-safe au sens
// "process sur le point de mourir" : utilisée aussi par le watchdog RSS.
void printBenchVerdict(const QString &jobId,
                       bool pass,
                       const QList<BenchFailure> &failures,
                       const QJsonObject &metrics,
                       qint64 durationMs);

#endif // BENCH_VERDICT_H
