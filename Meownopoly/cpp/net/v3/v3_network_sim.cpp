#include "v3_network_sim.h"

#include <algorithm>

void V3NetworkSim::reset(quint32 seed)
{
    m_rng.seed(seed);
    m_queue.clear();
    m_stats = Stats{};
    m_sendCounter = 0;
}

double V3NetworkSim::nextUnit()
{
    // [0,1) sans dépendre de std::uniform_real_distribution (portabilité de la
    // reproductibilité inter-plateformes : la distribution std n'est pas
    // garantie identique, la division de genrand l'est).
    return static_cast<double>(m_rng() - std::mt19937::min())
           / (static_cast<double>(std::mt19937::max() - std::mt19937::min()) + 1.0);
}

QByteArray V3NetworkSim::corrupt(const QByteArray &in)
{
    if (in.isEmpty()) return in;
    QByteArray out = in;
    // Altère un octet à une position aléatoire (flip d'un bit garanti non nul).
    const int pos = static_cast<int>(nextUnit() * out.size()) % out.size();
    const quint8 mask = static_cast<quint8>(1u << (m_rng() & 7u));
    out[pos] = static_cast<char>(static_cast<quint8>(out[pos]) ^ mask);
    return out;
}

void V3NetworkSim::send(const QByteArray &packet)
{
    ++m_stats.sent;
    const quint64 order = m_sendCounter++;

    // Perte : décidée en premier, absorbe tout le reste pour ce paquet.
    if (nextUnit() < m_cfg.lossRate) {
        ++m_stats.dropped;
        return;
    }

    // Nombre d'exemplaires : 1 de base, + éventuels doublons.
    int copies = 1;
    if (m_cfg.duplicateRate > 0.0 && nextUnit() < m_cfg.duplicateRate) {
        const int extra = 1 + static_cast<int>(nextUnit()
                              * static_cast<double>(qMax(1, m_cfg.maxDuplicates)));
        copies += qMin(extra, qMax(1, m_cfg.maxDuplicates));
        m_stats.duplicated += (copies - 1);
    }

    for (int c = 0; c < copies; ++c) {
        QByteArray bytes = packet;
        if (m_cfg.corruptRate > 0.0 && nextUnit() < m_cfg.corruptRate) {
            bytes = corrupt(bytes);
            ++m_stats.corrupted;
        }
        InFlight f;
        f.bytes = bytes;
        f.sendOrder = order;
        // Clé de brassage : mélange linéaire entre l'ordre FIFO (reorder=0) et
        // un tirage pur (reorder=1).
        const double jitter = nextUnit();
        f.shuffleKey = (1.0 - m_cfg.reorderRate) * static_cast<double>(order)
                       + m_cfg.reorderRate * jitter * static_cast<double>(m_sendCounter + 1);
        m_queue.append(f);
    }
}

QList<QByteArray> V3NetworkSim::deliver()
{
    std::stable_sort(m_queue.begin(), m_queue.end(),
                     [](const InFlight &a, const InFlight &b) {
                         if (a.shuffleKey != b.shuffleKey) return a.shuffleKey < b.shuffleKey;
                         return a.sendOrder < b.sendOrder;
                     });
    QList<QByteArray> out;
    out.reserve(m_queue.size());
    for (const InFlight &f : m_queue) out.append(f.bytes);
    m_stats.delivered += out.size();
    m_queue.clear();
    return out;
}
