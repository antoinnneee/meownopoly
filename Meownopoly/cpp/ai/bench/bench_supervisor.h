#ifndef MEOW_BENCH_SUPERVISOR_H
#define MEOW_BENCH_SUPERVISOR_H

// ============================================================================
// BenchSupervisor — supervision côté jeu du banc d'essai (doc 12 §2.2 / §5)
// ============================================================================
//
// Livrable de la tâche A3. Pilote l'exécutable jetable `meow_testbench` depuis
// le process du jeu :
//   - écrit le job JSON dans un fichier temporaire (l'entrée du banc est un
//     fichier, pas stdin — doc 12 §2.2, trivial à rejouer à la main) ;
//   - spawn le banc en `QProcess`, HEADLESS (`-platform offscreen`) et sans
//     surface réseau (l'exécutable ne lie aucun module réseau, doc 12 §5) ;
//   - applique un **timeout dur global** (`MEOW_BENCH_TIMEOUT_MS`, 30 s). Au
//     dépassement : `kill()` du process + verdict synthétique `bench_timeout` ;
//   - à la sortie : relit le verdict `MEOWBENCH:` sur stdout. Absence de
//     verdict / exit anormal ⇒ verdict synthétique `crash` (avec `exitCode`).
//
// INVARIANT (doc 12 §1) : **le jeu ne gèle jamais**. La supervision est donc
// entièrement ASYNCHRONE (signaux QProcess + QTimer) — aucun
// `waitForFinished()` bloquant sur le thread GUI. Le résultat arrive via le
// signal `verdictReady`. Une seule validation à la fois au MVP (la file
// transactionnelle D12 sérialise déjà les propositions) : `runJob` refuse un
// second job tant qu'un est en cours (`busy()`).
//
// Le banc n'est PAS déployé avec son plugin plateforme (build/Release ne
// contient que `qwindows` via le windeployqt du jeu). Le superviseur rend donc
// le plugin `offscreen` découvrable en injectant `QT_PLUGIN_PATH` (chemin des
// plugins de la build Qt courante, `QLibraryInfo`) dans l'environnement du
// process enfant.
// ============================================================================

#include <QObject>
#include <QString>
#include <QJsonObject>
#include <QProcess>

class QTimer;

// Timeout dur global côté superviseur (doc 12 §9). Derrière #define (D22) :
// le jeu est la source de vérité et peut le surcharger à la compilation.
#ifndef MEOW_BENCH_TIMEOUT_MS
#define MEOW_BENCH_TIMEOUT_MS 30000
#endif

class BenchSupervisor : public QObject
{
    Q_OBJECT

public:
    explicit BenchSupervisor(QObject *parent = nullptr);
    ~BenchSupervisor() override;

    // Chemin de l'exécutable du banc. Par défaut : résolu à côté de
    // l'application (`meow_testbench[.exe]`). Surchargeable pour les tests.
    void setBenchExecutablePath(const QString &path);
    QString benchExecutablePath() const { return m_benchExe; }

    // Timeout dur (ms). Défaut MEOW_BENCH_TIMEOUT_MS.
    void setTimeoutMs(int ms);
    int timeoutMs() const { return m_timeoutMs; }

    // true si un job est en cours (un seul à la fois au MVP).
    bool busy() const;

    // Lance la validation d'un job (doc 12 §2.3). Le job est sérialisé dans un
    // fichier temporaire puis passé au banc. Le verdict arrive de façon
    // asynchrone via `verdictReady`. No-op (warning) si `busy()`.
    void runJob(const QJsonObject &job);

signals:
    // Émis une fois par `runJob`, avec le verdict (réel ou synthétique, doc 12
    // §4). Toujours un objet verdict bien formé, même sur crash/timeout.
    void verdictReady(const QJsonObject &verdict);

private slots:
    void onFinished(int exitCode, QProcess::ExitStatus status);
    void onErrorOccurred(QProcess::ProcessError error);
    void onTimeout();

private:
    // Termine le cycle courant : coupe le timer, publie le verdict, nettoie.
    void finishWith(const QJsonObject &verdict);
    void cleanup();

    static QString resolveDefaultBenchPath();
    static QProcessEnvironment benchEnvironment();

    QProcess *m_process = nullptr;
    QTimer   *m_timer = nullptr;
    QString   m_benchExe;
    int       m_timeoutMs = MEOW_BENCH_TIMEOUT_MS;

    QString   m_jobId;          // corrélation des verdicts synthétiques
    QString   m_jobFilePath;    // fichier temporaire à supprimer
    bool      m_finished = false;
};

#endif // MEOW_BENCH_SUPERVISOR_H
