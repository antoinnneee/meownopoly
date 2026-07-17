#include "bench_verdict.h"

#include "ai/bench/bench_constants.h"

#include <QJsonArray>
#include <QJsonDocument>

#include <cstdio>

void printBenchVerdict(const QString &jobId,
                       bool pass,
                       const QList<BenchFailure> &failures,
                       const QJsonObject &metrics,
                       qint64 durationMs)
{
    QJsonArray failuresArray;
    for (const BenchFailure &f : failures) {
        QJsonObject o;
        o.insert(QStringLiteral("code"), f.code);
        o.insert(QStringLiteral("phase"), f.phase);
        o.insert(QStringLiteral("details"), f.details);
        o.insert(QStringLiteral("retryable"), f.retryable);
        failuresArray.append(o);
    }

    QJsonObject verdict;
    verdict.insert(QStringLiteral("jobId"), jobId);
    verdict.insert(QStringLiteral("benchVersion"), MEOW_BENCH_VERSION);
    verdict.insert(QStringLiteral("verdict"),
                   pass ? QStringLiteral("pass") : QStringLiteral("fail"));
    verdict.insert(QStringLiteral("failures"), failuresArray);
    verdict.insert(QStringLiteral("metrics"), metrics);
    verdict.insert(QStringLiteral("durationMs"), double(durationMs));

    const QByteArray line =
        QJsonDocument(verdict).toJson(QJsonDocument::Compact);
    // fputs + fflush plutôt que qDebug/QTextStream : la ligne doit sortir
    // même si le process est sur le point d'être abattu (watchdog RSS).
    std::fputs(MEOW_BENCH_VERDICT_PREFIX, stdout);
    std::fwrite(line.constData(), 1, size_t(line.size()), stdout);
    std::fputc('\n', stdout);
    std::fflush(stdout);
}
