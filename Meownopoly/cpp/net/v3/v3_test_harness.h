/*
 *      Meownopoly V3 — harnais de test de fiabilité réseau (B5)
 *
 * Banc de vérification hors-réseau des invariants M3 (audit v3/10 §M3, critères
 * d'acceptation). Fait passer les composants de fiabilité applicative V3
 * — V3ReliableTracker (B2), V3SupersedableState (B3), V3ChunkSender/Receiver
 * (B4) — à travers V3NetworkSim (canal fautif déterministe) et vérifie que
 * chaque critère M3 tient :
 *
 *   1. dédup exactly-once : une transaction/proposition n'est appliquée qu'une
 *      fois malgré retransmissions, duplication et réordonnancement ;
 *   2. chunk réparable : la perte (et la corruption) d'un fragment est détectée
 *      et réparée par re-demande, le payload reconstitué est exact ;
 *   3. état supersédable : seule la valeur la plus récente est appliquée, le
 *      retard/réordre est ignoré, un snapshot répare les deltas perdus ;
 *   4. échec explicite : une panne réseau bornée aboutit à un échec définitif
 *      remonté, jamais à un succès silencieux.
 *
 * Aucune I/O, aucune dépendance Qt GUI ni réseau, aucun `main()` : c'est une
 * classe utilitaire compilée dans le binaire principal (via le GLOB), invocable
 * depuis un hook d'automation ou un futur point d'entrée de test. Déterministe
 * (graine) → tout échec est rejouable à l'identique.
 */
#ifndef V3_TEST_HARNESS_H
#define V3_TEST_HARNESS_H

#include <QList>
#include <QString>
#include <QtGlobal>

class V3TestHarness
{
public:
    struct Result {
        QString name;      ///< Nom du scénario.
        bool    passed = false;
        QString detail;    ///< Métriques / cause d'échec (rejouable).
    };

    /// Exécute tous les scénarios avec une graine donnée. Chaque scénario
    /// réinitialise son propre simulateur à partir de cette graine (dérivée) →
    /// indépendance et reproductibilité.
    static QList<Result> runAll(quint32 seed = 0xB5C0FFEEu);

    /// Rapport texte agrégé (une ligne par scénario + résumé PASS/FAIL).
    static QString runAllToString(quint32 seed = 0xB5C0FFEEu);

    /// True si tous les scénarios passent.
    static bool allPass(quint32 seed = 0xB5C0FFEEu);

    // Scénarios individuels (exposés pour usage ciblé / débogage).
    static Result scenarioDedupExactlyOnce(quint32 seed); ///< Critère 1 (B2).
    static Result scenarioChunkRepair(quint32 seed);      ///< Critère 2 (B4).
    static Result scenarioSupersede(quint32 seed);        ///< Critère 3 (B3).
    static Result scenarioBoundedOutageFails();           ///< Critère 4 (B2).
};

#endif // V3_TEST_HARNESS_H
