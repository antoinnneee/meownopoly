/*
 *      Meownopoly V3 — simulateur de canal fautif (B5)
 *
 * Canal réseau déterministe à injection de fautes, pour éprouver la fiabilité
 * applicative V3 (B2 dédup/retry, B3 supersession, B4 chunking réparable) sans
 * dépendre d'un vrai transport UDP. Reproduit les quatre familles de fautes des
 * critères d'acceptation M3 (audit v3/10 §M3) :
 *
 *   - PERTE            : un paquet est jeté (jamais délivré) ;
 *   - DUPLICATION      : un paquet est délivré en plusieurs exemplaires ;
 *   - RÉORDONNANCEMENT : l'ordre de délivrance diffère de l'ordre d'émission ;
 *   - CORRUPTION       : un ou plusieurs octets d'un paquet sont altérés.
 *
 * Entièrement déterministe (RNG `std::mt19937` graine fixe) → un scénario qui
 * échoue est rejouable à l'identique. Aucune I/O, aucune dépendance Qt GUI :
 * QtCore uniquement, mono-thread. Modèle simple « boîte » : on `send()` des
 * paquets (les fautes sont décidées à l'émission), puis `deliver()` vide la
 * file en la réordonnant aléatoirement.
 *
 * Ce n'est PAS un modèle de latence/fenêtre fidèle à reliable.io : c'est un
 * banc adversarial minimal dont le seul but est de prouver que les composants
 * V3 tiennent leurs invariants (livraison exactly-once, réparation, échec
 * explicite jamais silencieux) face à un canal hostile.
 */
#ifndef V3_NETWORK_SIM_H
#define V3_NETWORK_SIM_H

#include <QByteArray>
#include <QList>
#include <QtGlobal>

#include <random>

class V3NetworkSim
{
public:
    /// Probabilités par paquet (0.0 = jamais, 1.0 = toujours). Combinables :
    /// un paquet peut être dupliqué ET corrompu, etc. La perte l'emporte (un
    /// paquet perdu n'est ni dupliqué ni corrompu).
    struct Config {
        double lossRate       = 0.0; ///< P(paquet jeté).
        double duplicateRate  = 0.0; ///< P(un exemplaire supplémentaire délivré).
        double reorderRate    = 0.0; ///< Intensité du brassage (0 = ordre FIFO préservé).
        double corruptRate    = 0.0; ///< P(un exemplaire délivré est altéré).
        int    maxDuplicates  = 2;   ///< Exemplaires supplémentaires max sur un « hit » dup.
    };

    /// Compteurs cumulés (introspection / assertions de couverture des tests).
    struct Stats {
        int sent        = 0;
        int dropped     = 0;
        int duplicated  = 0; ///< Exemplaires supplémentaires générés (au-delà du 1er).
        int corrupted   = 0; ///< Exemplaires altérés.
        int delivered   = 0; ///< Exemplaires effectivement sortis par deliver().
    };

    explicit V3NetworkSim(quint32 seed = 0xC0FFEEu) : m_rng(seed) {}

    void setConfig(const Config &cfg) { m_cfg = cfg; }
    const Config &config() const { return m_cfg; }
    const Stats  &stats()  const { return m_stats; }

    /// Réinitialise la file en transit, les stats et la graine du RNG.
    void reset(quint32 seed);

    /// Soumet un paquet au canal. Les fautes (perte/dup/corruption) sont
    /// décidées ici ; les exemplaires survivants sont mis en file avec une clé
    /// d'ordre aléatoire (support du réordonnancement à la délivrance).
    void send(const QByteArray &packet);

    /// Vide la file en transit et retourne les paquets prêts, réordonnés selon
    /// `reorderRate` (0 → ordre d'émission préservé ; 1 → brassage complet).
    QList<QByteArray> deliver();

    /// Paquets encore en transit (non encore délivrés).
    int inFlight() const { return m_queue.size(); }

private:
    // Un exemplaire en transit : octets + rang d'émission + clé de brassage.
    struct InFlight {
        QByteArray bytes;
        quint64    sendOrder = 0; ///< Ordre FIFO d'émission (départage stable).
        double     shuffleKey = 0.0;
    };

    double nextUnit();                         ///< tirage uniforme [0,1).
    QByteArray corrupt(const QByteArray &in);  ///< altère ≥1 octet.

    Config             m_cfg;
    Stats              m_stats;
    std::mt19937       m_rng;
    QList<InFlight>    m_queue;
    quint64            m_sendCounter = 0;
};

#endif // V3_NETWORK_SIM_H
