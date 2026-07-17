#ifndef BENCH_JOB_H
#define BENCH_JOB_H

// ============================================================================
// Parsing/validation du job JSON du banc (doc/v3/12_BANC_ESSAI_R1.md §2.3).
// Un échec de parsing/validation produit le code `job_invalid`.
// ============================================================================

#include <QJsonArray>
#include <QJsonObject>
#include <QString>

struct BenchJob
{
    QString jobId;
    int benchVersion = 0;

    QJsonObject snapshotMap;     // sérialisation map : mapInfo + snapableTiles
    QJsonObject snapshotMemory;  // réservé (doc 05) — ignoré au squelette
    QJsonObject snapshotModules; // réservé (D41) — ignoré au squelette

    QJsonObject artifact; // squelette : validé présent, jamais instancié
    QJsonObject budgets;  // valeurs D34 sérialisées (source de vérité : le jeu)
    QJsonArray stimuli;   // scénarios P4 — ignorés au squelette
    quint32 seed = 0;     // seed de toute source d'aléa (reproductibilité R1)
};

struct BenchJobParseResult
{
    bool ok = false;
    QString details; // exploitable par un LLM (doc 12 §4)
    BenchJob job;
};

// Lit et valide le fichier de job. Toute erreur (fichier illisible, JSON
// invalide, champ obligatoire manquant) → ok=false, code job_invalid.
BenchJobParseResult parseBenchJobFile(const QString &path);

#endif // BENCH_JOB_H
