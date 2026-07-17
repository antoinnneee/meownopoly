#include "v3_test_harness.h"

#include "v3_chunk_transfer.h"
#include "v3_envelope.h"
#include "v3_network_sim.h"
#include "v3_protocol.h"
#include "v3_reliable_tracker.h"
#include "v3_supersedable_state.h"

#include <QHash>
#include <QJsonDocument>
#include <QJsonObject>

#include <random>

namespace {

// Encode un frame chunk en octets fil (JSON compact), comme le ferait le
// consommateur en l'insérant dans un payload d'enveloppe.
QByteArray frameToBytes(const V3ChunkDataFrame &f)
{
    return QJsonDocument(f.toJson()).toJson(QJsonDocument::Compact);
}

// Payload déterministe pseudo-aléatoire de `size` octets.
QByteArray makePayload(int size, quint32 seed)
{
    std::mt19937 rng(seed);
    QByteArray out;
    out.resize(size);
    for (int i = 0; i < size; ++i)
        out[i] = static_cast<char>(rng() & 0xFF);
    return out;
}

} // namespace

// ── Critère 1 — dédup exactly-once malgré retransmission/dup/réordre (B2) ─────
V3TestHarness::Result V3TestHarness::scenarioDedupExactlyOnce(quint32 seed)
{
    Result r; r.name = QStringLiteral("dedup_exactly_once");

    V3NetworkSim sim(seed);
    // Pas de corruption ici : la dédup s'appuie sur `messageId`, un champ
    // d'en-tête d'enveloppe que `payloadHash` ne protège PAS (il ne couvre que
    // le payload). Sur le fil réel, une corruption d'octet est attrapée sous la
    // couche V3 par le CRC par-paquet de reliable.io ; la corruption est donc
    // éprouvée là où V3 la gère explicitement — le chunking B4 et ses checksums
    // (scénario chunk_repair). Ici on éprouve perte + duplication + réordre.
    sim.setConfig({ /*loss*/0.40, /*dup*/0.30, /*reorder*/0.90, /*corrupt*/0.0, /*maxDup*/3 });

    const QString peer = QStringLiteral("peerA");
    const QString session = QStringLiteral("sess-1");
    const int N = 24;

    QList<V3Envelope> msgs;
    for (int i = 0; i < N; ++i) {
        QJsonObject payload{ { QStringLiteral("n"), i } };
        msgs.append(V3Envelope::create(session, QStringLiteral("author"),
                                       QStringLiteral("tx.commit"),
                                       static_cast<quint64>(i + 1), payload));
    }

    V3ReliableTracker rx;                 // dédup côté réception
    QHash<QString, int> appDeliveries;    // messageId → nb de livraisons applicatives

    const int maxRounds = 20;
    for (int round = 0; round < maxRounds; ++round) {
        // L'émetteur retransmet TOUT à chaque tour (surapproximation du retry) —
        // le récepteur doit encaisser sans jamais livrer deux fois.
        for (const V3Envelope &env : msgs)
            sim.send(V3Protocol::pack(env));

        const QList<QByteArray> arrived = sim.deliver();
        for (const QByteArray &bytes : arrived) {
            V3MessageType::Value type;
            V3Envelope env;
            if (!V3Protocol::unpack(bytes, type, env))
                continue;                     // corruption structurelle → drop
            if (!env.verifyPayloadHash())
                continue;                     // payload corrompu → drop
            if (rx.registerIncoming(peer, env.messageId))
                appDeliveries[env.messageId] += 1;   // 1re livraison unique
        }
    }

    // Invariant 1 : chaque message livré au plus une fois.
    int overDelivered = 0, maxCount = 0;
    for (auto it = appDeliveries.constBegin(); it != appDeliveries.constEnd(); ++it) {
        maxCount = qMax(maxCount, it.value());
        if (it.value() > 1) ++overDelivered;
    }
    // Invariant 2 : retry a vaincu la perte → tous finissent par arriver.
    const int uniqueDelivered = appDeliveries.size();

    r.passed = (overDelivered == 0) && (uniqueDelivered == N)
               && (sim.stats().duplicated > 0) && (sim.stats().dropped > 0);
    r.detail = QStringLiteral("unique=%1/%2 maxCopiesDelivered=%3 overDelivered=%4 "
                              "(sim dropped=%5 dup=%6)")
                   .arg(uniqueDelivered).arg(N).arg(maxCount).arg(overDelivered)
                   .arg(sim.stats().dropped).arg(sim.stats().duplicated);
    return r;
}

// ── Critère 2 — perte/corruption d'un chunk détectée et réparée (B4) ─────────
V3TestHarness::Result V3TestHarness::scenarioChunkRepair(quint32 seed)
{
    Result r; r.name = QStringLiteral("chunk_repair");

    V3NetworkSim sim(seed);
    sim.setConfig({ /*loss*/0.30, /*dup*/0.20, /*reorder*/0.80, /*corrupt*/0.10, /*maxDup*/2 });

    const QByteArray original = makePayload(40 * 1024, seed ^ 0x1234u);
    V3ChunkSender sender;
    V3ChunkReceiver receiver;

    qint64 now = 0;
    const QString tid = sender.begin(original, /*capacity*/1024, now);

    int corruptSeen = 0, checksumMismatchSeen = 0, dupSeen = 0;
    bool completed = false;
    QByteArray result;

    QList<V3ChunkDataFrame> batch = sender.allFrames(tid);
    const int maxRounds = 60;
    int rounds = 0;
    for (; rounds < maxRounds && !completed; ++rounds) {
        now += 100;
        for (const V3ChunkDataFrame &f : batch)
            sim.send(frameToBytes(f));

        const QList<QByteArray> arrived = sim.deliver();
        for (const QByteArray &bytes : arrived) {
            QJsonParseError err;
            const QJsonDocument doc = QJsonDocument::fromJson(bytes, &err);
            if (err.error != QJsonParseError::NoError || !doc.isObject())
                continue;                     // corruption a cassé le JSON → perte
            V3ChunkDataFrame f;
            if (!V3ChunkDataFrame::fromJson(doc.object(), f))
                continue;
            QByteArray out;
            switch (receiver.accept(f, now, out)) {
            case V3ChunkAccept::Complete:         completed = true; result = out; break;
            case V3ChunkAccept::Corrupt:          ++corruptSeen; break;
            case V3ChunkAccept::ChecksumMismatch: ++checksumMismatchSeen; break;
            case V3ChunkAccept::Duplicate:        ++dupSeen; break;
            default: break;
            }
        }
        if (completed) break;

        // Réparation : demander les fragments encore manquants.
        bool requested = false;
        const V3ChunkRequestFrame req = receiver.buildRequest(tid, requested);
        batch = sender.serveRequest(req, now);
        if (batch.isEmpty()) {
            // Le récepteur n'a encore rien reçu (tout le 1er lot perdu) → renvoi
            // intégral. Sinon il ne manquerait rien alors que le transfert est
            // incomplet, ce qui n'arrive pas.
            batch = sender.allFrames(tid);
        }
    }

    const bool payloadExact = completed && (result == original);
    // Le canal doit avoir été réellement hostile (sinon le test ne prouve rien).
    const bool channelWasHostile = sim.stats().dropped > 0;
    // Réparation effective : plus d'un tour a été nécessaire.
    const bool repaired = rounds > 1;

    r.passed = payloadExact && channelWasHostile && repaired;
    r.detail = QStringLiteral("complete=%1 exact=%2 rounds=%3 corruptCaught=%4 "
                              "checksumMismatch=%5 dupIgnored=%6 (sim dropped=%7 corrupt=%8)")
                   .arg(completed).arg(result == original).arg(rounds)
                   .arg(corruptSeen).arg(checksumMismatchSeen).arg(dupSeen)
                   .arg(sim.stats().dropped).arg(sim.stats().corrupted);
    return r;
}

// ── Critère 3 — état supersédable : drop de l'ancien + réparation snapshot ────
V3TestHarness::Result V3TestHarness::scenarioSupersede(quint32 seed)
{
    Result r; r.name = QStringLiteral("supersede_state");

    V3NetworkSim sim(seed);
    // Corruption exclue (cf. dedup) : `seq` est un champ d'en-tête d'enveloppe
    // non couvert par `payloadHash` ; l'intégrité d'octet relève de reliable.io
    // sous la couche V3. B3 gère perte + duplication + réordonnancement des
    // deltas, et répare la perte par snapshot.
    sim.setConfig({ /*loss*/0.35, /*dup*/0.25, /*reorder*/0.95, /*corrupt*/0.0, /*maxDup*/2 });

    const QString session = QStringLiteral("sess-state");
    const QString key = QStringLiteral("tile-42/hp");
    const int M = 40;

    // Producteur : émet M mises à jour à séquence croissante pour la même clé.
    for (int s = 1; s <= M; ++s) {
        QJsonObject payload{ { QStringLiteral("hp"), 200 - s } };
        const V3Envelope env = V3Envelope::create(session, QStringLiteral("host"),
                                                  QStringLiteral("state.update"),
                                                  static_cast<quint64>(s), payload);
        sim.send(V3Protocol::pack(env));
    }

    V3SupersedableState rx;
    quint64 maxDeliveredSeq = 0;
    int applied = 0, dup = 0, stale = 0;
    bool regressed = false;
    quint64 lastAppliedSeq = 0;

    const QList<QByteArray> arrived = sim.deliver();
    for (const QByteArray &bytes : arrived) {
        V3MessageType::Value type;
        V3Envelope env;
        if (!V3Protocol::unpack(bytes, type, env)) continue;
        if (!env.verifyPayloadHash()) continue;
        maxDeliveredSeq = qMax(maxDeliveredSeq, env.seq);
        switch (rx.offer(key, env.seq)) {
        case V3SupersedeVerdict::Applied:
            ++applied;
            if (env.seq <= lastAppliedSeq) regressed = true; // ne doit jamais arriver
            lastAppliedSeq = env.seq;
            break;
        case V3SupersedeVerdict::Duplicate: ++dup; break;
        case V3SupersedeVerdict::Stale:     ++stale; break;
        }
    }

    // Invariant : après réception, la clé reflète la plus haute séquence reçue,
    // jamais une plus ancienne, et aucune application n'a régressé.
    const bool convergedToNewest = (rx.lastSeq(key) == maxDeliveredSeq);

    // Réparation : le producteur émet le socle réel (M) via un snapshot. Même si
    // le delta M a été perdu, le récepteur doit rattraper la vérité producteur.
    V3StateSnapshot snap;
    snap.snapshotSeq = 1;
    snap.keySeqs.insert(key, static_cast<quint64>(M));
    const bool snapApplied = rx.applySnapshot(snap);
    const bool repairedToTruth = (rx.lastSeq(key) == static_cast<quint64>(M));

    // Un snapshot obsolète (socle inférieur) ne doit pas régresser la clé.
    V3StateSnapshot stale2;
    stale2.snapshotSeq = 2;
    stale2.keySeqs.insert(key, 1);
    rx.applySnapshot(stale2);
    const bool noRegressionOnStaleSnap = (rx.lastSeq(key) == static_cast<quint64>(M));

    r.passed = !regressed && convergedToNewest && snapApplied
               && repairedToTruth && noRegressionOnStaleSnap;
    r.detail = QStringLiteral("applied=%1 stale=%2 dup=%3 lastSeq=%4 maxDelivered=%5 "
                              "repairedTo=%6/%7 noStaleRegress=%8")
                   .arg(applied).arg(stale).arg(dup)
                   .arg(rx.lastSeq(key)).arg(maxDeliveredSeq)
                   .arg(repairedToTruth).arg(M).arg(noRegressionOnStaleSnap);
    return r;
}

// ── Critère 4 — panne bornée → échec explicite, jamais succès silencieux ─────
V3TestHarness::Result V3TestHarness::scenarioBoundedOutageFails()
{
    Result r; r.name = QStringLiteral("bounded_outage_fails");

    V3ReliableTracker tx;
    const QString peer = QStringLiteral("peerDead");
    const QByteArray packet("dummy-packet");

    tx.trackSend(peer, QStringLiteral("m1"), packet, /*seq*/1, /*now*/0, /*rtt*/50.0);

    qint64 now = 0;
    bool failed = false;
    int attempts = 1;
    // Panne totale : aucun ACK n'arrivera jamais. On avance le temps assez pour
    // rendre chaque retransmission due, jusqu'à épuisement des tentatives.
    for (int i = 0; i < V3ReliableTracker::kMaxSendAttempts + 4 && !failed; ++i) {
        now += V3ReliableTracker::kRetryMaxMs * 2;
        QList<V3PendingSend> outFailed;
        const QList<V3PendingSend *> due = tx.collectDue(peer, now, outFailed);
        if (!outFailed.isEmpty()) {
            failed = true;
            attempts = outFailed.first().sendCount;
            break;
        }
        for (V3PendingSend *e : due) {
            attempts = e->sendCount;
            tx.markResent(e, /*newSeq*/e->seq, now, 50.0);
        }
    }

    // Aucun ACK n'a jamais confirmé le message (succès silencieux interdit).
    const QStringList confirmed = tx.confirmAcks(peer, nullptr, 0);
    const bool noSilentSuccess = confirmed.isEmpty();
    // Après échec définitif, la file est vidée du message.
    const bool purged = (tx.pendingCount(peer) == 0);

    r.passed = failed && noSilentSuccess && purged
               && (attempts <= V3ReliableTracker::kMaxSendAttempts);
    r.detail = QStringLiteral("failed=%1 attempts=%2 (cap=%3) noSilentSuccess=%4 purged=%5")
                   .arg(failed).arg(attempts).arg(V3ReliableTracker::kMaxSendAttempts)
                   .arg(noSilentSuccess).arg(purged);
    return r;
}

// ── Agrégation ───────────────────────────────────────────────────────────────
QList<V3TestHarness::Result> V3TestHarness::runAll(quint32 seed)
{
    // Graines dérivées : scénarios indépendants mais tous reproductibles.
    return {
        scenarioDedupExactlyOnce(seed ^ 0x0001u),
        scenarioChunkRepair(seed ^ 0x0002u),
        scenarioSupersede(seed ^ 0x0003u),
        scenarioBoundedOutageFails(),
    };
}

QString V3TestHarness::runAllToString(quint32 seed)
{
    const QList<Result> results = runAll(seed);
    QString out;
    int passCount = 0;
    for (const Result &res : results) {
        if (res.passed) ++passCount;
        out += QStringLiteral("[%1] %2 — %3\n")
                   .arg(res.passed ? QStringLiteral("PASS") : QStringLiteral("FAIL"),
                        res.name, res.detail);
    }
    out += QStringLiteral("=== V3 harness: %1/%2 PASS (seed=0x%3) ===")
               .arg(passCount).arg(results.size()).arg(seed, 0, 16);
    return out;
}

bool V3TestHarness::allPass(quint32 seed)
{
    const QList<Result> results = runAll(seed);
    for (const Result &res : results)
        if (!res.passed) return false;
    return true;
}
