#ifndef BENCH_SUPERVISOR_H
#define BENCH_SUPERVISOR_H

// ============================================================================
// BenchSupervisor — superviseur côté jeu du banc d'essai hors-process
// (doc/v3/12_BANC_ESSAI_R1.md §2.2, tâche A3 du plan doc/v3/15).
//
// Rôle : écrire le job JSON dans un fichier temporaire, lancer
// `meow_testbench -platform offscreen <job.json>` via QProcess, appliquer le
// timeout dur MEOW_BENCH_TIMEOUT_MS (kill + verdict synthétique
// `bench_timeout`), détecter le crash (exit != 0 sans ligne MEOWBENCH →
// `crash`), parser la ligne `MEOWBENCH:` et émettre verdictReady(QJsonObject).
//
// Squelette M9.1 : pas encore branché à l'UI ni enregistré côté QML (ce sera
// M1/S-1). Une seule validation à la fois (la file transactionnelle D12
// sérialise en amont) — runJob() refuse si un job est déjà en cours.
// ============================================================================

#include <QJsonObject>
#include <QObject>
#include <QProcess>
#include <QTimer>

class BenchSupervisor : public QObject
{
    Q_OBJECT

public:
    explicit BenchSupervisor(QObject *parent = nullptr);
    ~BenchSupervisor() override;

    // Chemin de l'exécutable du banc. Défaut : MEOW_BENCH_EXE_NAME(.exe) à
    // côté de l'exécutable du jeu (même RUNTIME_OUTPUT_DIRECTORY, cf. CMake).
    QString benchExecutablePath() const;
    void setBenchExecutablePath(const QString &path);

    bool busy() const { return m_process != nullptr; }

    // Lance une validation. Retourne false (sans rien émettre) si un job est
    // déjà en cours ou si le job ne peut pas être écrit sur disque — dans ce
    // dernier cas un verdict synthétique `job_invalid` est émis.
    Q_INVOKABLE bool runJob(const QJsonObject &job);

signals:
    // Verdict final — soit la ligne MEOWBENCH: parsée, soit un verdict
    // synthétique (bench_timeout / crash / job_invalid).
    void verdictReady(const QJsonObject &verdict);

private slots:
    void onProcessFinished(int exitCode, QProcess::ExitStatus status);
    void onProcessError(QProcess::ProcessError error);
    void onTimeout();

private:
    // Verdict synthétique au format doc 12 §4 (une failure unique).
    QJsonObject syntheticVerdict(const QString &code,
                                 const QString &details,
                                 const QJsonObject &extra = {}) const;
    void emitVerdictOnce(const QJsonObject &verdict);
    void cleanupProcess();

    QProcess *m_process = nullptr;
    QTimer m_timeoutTimer;
    QString m_benchExecutablePath; // vide = résolution par défaut
    QString m_jobFilePath;         // fichier temp du job en cours
    QString m_jobId;               // jobId du job en cours (verdicts synthétiques)
    bool m_verdictEmitted = false;
    bool m_killedByTimeout = false;
};

#endif // BENCH_SUPERVISOR_H
