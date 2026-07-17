#include "gameplay_event_bus.h"

#include <utility>

#include <QDateTime>
#include <QTimeZone>
#include <QJsonObject>
#include <QThread>
#include <QTimer>
#include <QUuid>
#include <QtQml>

#include "game/game.h"
#include "editor/ops/editor_op_bus.h"
#include "game/physics/item_snapable_events.h"
#include "game/physics/physics_session.h"
#include "game/item_snapable/ItemSnapable.h"

// ==================== event_types helpers ====================

namespace meow {

EventDurability durabilityOf(EventType type)
{
    switch (type) {
    // Éphémères : haute fréquence ou purement visuels, non archivés dans
    // le noyau d'audit (D2). Diffusés quand même sur eventPublished.
    case EventType::TileMoved:
    case EventType::ZoneParameterChanged:
    case EventType::CombatRequest:
        return EventDurability::Ephemeral;
    // Tout le reste est durable (structure de carte, cycle de vie, ops,
    // résolution de combat).
    default:
        return EventDurability::Durable;
    }
}

QString eventTypeName(EventType type)
{
    switch (type) {
    case EventType::GameStarted:          return QStringLiteral("GameStarted");
    case EventType::MapLoaded:            return QStringLiteral("MapLoaded");
    case EventType::MapCleared:           return QStringLiteral("MapCleared");
    case EventType::TileRemovedGame:      return QStringLiteral("TileRemovedGame");
    case EventType::MapRestored:          return QStringLiteral("MapRestored");
    case EventType::EditorOpLocal:        return QStringLiteral("EditorOpLocal");
    case EventType::EditorOpRemote:       return QStringLiteral("EditorOpRemote");
    case EventType::TileCreated:          return QStringLiteral("TileCreated");
    case EventType::TileDeleted:          return QStringLiteral("TileDeleted");
    case EventType::TileMoved:            return QStringLiteral("TileMoved");
    case EventType::ZoneParameterChanged: return QStringLiteral("ZoneParameterChanged");
    case EventType::CombatRequest:        return QStringLiteral("CombatRequest");
    case EventType::CombatResolved:       return QStringLiteral("CombatResolved");
    case EventType::Unknown:              break;
    }
    return QStringLiteral("Unknown");
}

QString eventSourceName(EventSource source)
{
    switch (source) {
    case EventSource::Game:      return QStringLiteral("Game");
    case EventSource::EditorOps: return QStringLiteral("EditorOps");
    case EventSource::Tiles:     return QStringLiteral("Tiles");
    case EventSource::Physics:   return QStringLiteral("Physics");
    case EventSource::System:    return QStringLiteral("System");
    case EventSource::Unknown:   break;
    }
    return QStringLiteral("Unknown");
}

QVariantMap GameplayEvent::toVariantMap() const
{
    QVariantMap m;
    m.insert(QStringLiteral("id"), id);
    m.insert(QStringLiteral("type"), static_cast<int>(type));
    m.insert(QStringLiteral("typeName"), eventTypeName(type));
    m.insert(QStringLiteral("source"), static_cast<int>(source));
    m.insert(QStringLiteral("sourceName"), eventSourceName(source));
    m.insert(QStringLiteral("author"), author);
    m.insert(QStringLiteral("logicalTs"), logicalTs);
    m.insert(QStringLiteral("causeId"), causeId);
    m.insert(QStringLiteral("version"), static_cast<int>(version));
    m.insert(QStringLiteral("durable"), durability == EventDurability::Durable);
    m.insert(QStringLiteral("wallTs"), wallTs);
    m.insert(QStringLiteral("seq"), seq);
    m.insert(QStringLiteral("rootId"), rootId);
    m.insert(QStringLiteral("depth"), depth);
    m.insert(QStringLiteral("payload"), payload);
    return m;
}

} // namespace meow

// ==================== GameplayEventBus ====================

GameplayEventBus *GameplayEventBus::m_instance = nullptr;

GameplayEventBus *GameplayEventBus::instance()
{
    if (!m_instance) m_instance = new GameplayEventBus();
    return m_instance;
}

QObject *GameplayEventBus::qmlInstance(QQmlEngine *, QJSEngine *)
{
    GameplayEventBus *inst = GameplayEventBus::instance();
    // Le singleton est aussi consommé côté C++ (ingestion, futur canal IA) →
    // garder l'ownership C++ pour éviter la destruction avec l'engine.
    QQmlEngine::setObjectOwnership(inst, QQmlEngine::CppOwnership);
    return inst;
}

void GameplayEventBus::registerQml()
{
    qRegisterMetaType<meow::GameplayEvent>();
    qmlRegisterSingletonType<GameplayEventBus>(
        "MeowEvents", 1, 0, "GameplayEventBus",
        &GameplayEventBus::qmlInstance);
}

GameplayEventBus::GameplayEventBus(QObject *parent)
    : QObject(parent)
{
    m_journal.reserve(256);
}

// ---- Horloge de Lamport dédiée aux événements -----------------------------
//
// On NE réutilise PAS Game::tickLamport() : cette horloge-là pilote le zOrder
// des tuiles (game_lamport.cpp) et progresse par pose de tuile ; la cadencer
// au rythme des événements métier (jusqu'à 30 Hz côté physique) la ferait
// dériver et empièterait sur les zLayers. On garde donc un compteur logique
// dédié, mais de MÊME principe (monotone, +1 par event local, sync au max sur
// réception d'un ts distant).

qint64 GameplayEventBus::tickLamport()
{
    return ++m_logicalClock;
}

void GameplayEventBus::syncLogicalClock(qint64 remoteTs)
{
    if (remoteTs > m_logicalClock) {
        m_logicalClock = remoteTs;
        emit eventCountChanged(); // rafraîchit la Q_PROPERTY logicalClock
    }
}

// ---- Publication / ingestion ----------------------------------------------

QString GameplayEventBus::publish(int type, int source, const QString &author,
                                  const QVariantMap &payload, const QString &causeId)
{
    meow::GameplayEvent ev;
    ev.id         = QUuid::createUuid().toString(QUuid::WithoutBraces);
    ev.type       = static_cast<meow::EventType>(type);
    ev.source     = static_cast<meow::EventSource>(source);
    ev.author     = author.isEmpty() ? QStringLiteral("local") : author;
    ev.causeId    = causeId;
    ev.durability = meow::durabilityOf(ev.type);
    ev.version    = meow::kGameplayEventSchemaVersion;
    ev.wallTs     = QDateTime::currentMSecsSinceEpoch();
    // logicalTs est attribué dans ingest(), sur le thread du bus, pour que le
    // compteur ne soit muté que là (pas de course).
    dispatchIngest(ev);
    return ev.id;
}

void GameplayEventBus::dispatchIngest(const meow::GameplayEvent &ev)
{
    if (QThread::currentThread() == thread()) {
        ingest(ev);
    } else {
        // Appel hors thread (ex. un futur émetteur côté worker physique) :
        // ré-ordonnancer sur le thread du bus.
        QMetaObject::invokeMethod(this,
            [this, ev]() { ingest(ev); },
            Qt::QueuedConnection);
    }
}

// ---- D3 : file transactionnelle + garde-fous de cascade (D12) --------------
//
// ingest() ne traite jamais un événement en ré-entrance. Il l'empile et, si un
// drainage n'est pas déjà en cours, il draine la file en série. Ainsi, quand un
// abonné de eventPublished re-publie (cascade de règle runtime, T4-4), le nouvel
// événement est mis en file et traité APRÈS l'événement courant, pas au milieu
// de son émission. La file est bornée (k_maxQueue) contre l'emballement.

void GameplayEventBus::ingest(meow::GameplayEvent ev)
{
    if (m_pending.size() >= k_maxQueue) {
        ++m_rejectedCount;
        emit protectionTriggered(QStringLiteral("queue"), ev.toVariantMap());
        return;
    }
    m_pending.enqueue(std::move(ev));
    if (m_draining) return;   // le drainage courant prendra cet événement
    drainQueue();
}

void GameplayEventBus::drainQueue()
{
    m_draining = true;
    while (!m_pending.isEmpty()) {
        meow::GameplayEvent ev = m_pending.dequeue();
        if (admit(ev))
            commit(std::move(ev));
    }
    m_draining = false;

    // La file est tarie : la cascade est close. On purge l'état causal pour ne
    // pas croître indéfiniment ni corréler des cascades indépendantes.
    m_depthOf.clear();
    m_rootOf.clear();
    m_cascadeCount.clear();
    m_writeHits.clear();
}

QString GameplayEventBus::writeTargetOf(const meow::GameplayEvent &ev)
{
    for (const char *k : { "tileId", "target", "key" }) {
        const QString key = QString::fromLatin1(k);
        if (ev.payload.contains(key)) {
            const QString v = ev.payload.value(key).toString();
            if (!v.isEmpty()) return v;
        }
    }
    return {};
}

bool GameplayEventBus::admit(meow::GameplayEvent &ev)
{
    // Racine : événement sans cause (émis directement par une source). On le
    // laisse toujours passer — les garde-fous ne visent que les cascades.
    if (ev.causeId.isEmpty()) {
        ev.rootId = ev.id;
        ev.depth  = 0;
        m_depthOf.insert(ev.id, 0);
        m_rootOf.insert(ev.id, ev.id);
        return true;
    }

    // Descendant : hérite racine + profondeur du parent. Si le parent est
    // inconnu (évincé de l'état causal), on le traite comme une racine de
    // secours pour éviter de bloquer indûment un causeId cross-cascade.
    const QString rootId = m_rootOf.value(ev.causeId, ev.causeId);
    const quint32 depth  = m_depthOf.value(ev.causeId, 0) + 1;
    ev.rootId = rootId;
    ev.depth  = depth;

    // 1) Profondeur max de la chaîne causale.
    if (depth > k_maxDepth) {
        ++m_rejectedCount;
        emit protectionTriggered(QStringLiteral("depth"), ev.toVariantMap());
        return false;
    }

    // 2) Budget de cascade : nombre total de descendants admis par racine.
    int &count = m_cascadeCount[rootId];
    if (count >= k_maxCascade) {
        ++m_rejectedCount;
        emit protectionTriggered(QStringLiteral("budget"), ev.toVariantMap());
        return false;
    }

    // 3) Détection de cycle via write-set : une même cible réécrite en boucle
    //    dans la même cascade trahit une règle qui se re-déclenche elle-même.
    const QString target = writeTargetOf(ev);
    if (!target.isEmpty()) {
        int &hits = m_writeHits[rootId][target];
        if (hits >= k_maxWriteHits) {
            ++m_rejectedCount;
            emit protectionTriggered(QStringLiteral("cycle"), ev.toVariantMap());
            return false;
        }
        ++hits;
    }

    ++count;
    m_depthOf.insert(ev.id, depth);
    m_rootOf.insert(ev.id, rootId);
    return true;
}

void GameplayEventBus::commit(meow::GameplayEvent ev)
{
    ev.logicalTs = tickLamport();
    ev.seq       = m_nextSeq++;   // séquence d'audit strictement monotone (D2)

    m_journal.append(ev);
    if (m_journal.size() > k_journalCap)
        m_journal.remove(0, m_journal.size() - k_journalCap);

    // Noyau d'audit non désactivable (D19) : seuls les durables, rétention
    // configurable, indépendante du journal général.
    if (ev.durability == meow::EventDurability::Durable) {
        m_auditLog.append(ev);
        if (m_auditRetention > 0 && m_auditLog.size() > m_auditRetention)
            m_auditLog.remove(0, m_auditLog.size() - m_auditRetention);
    }

    ++m_eventCount;
    emit eventCountChanged();
    emit eventPublished(ev.toVariantMap());
}

quint64 GameplayEventBus::oldestSeq() const
{
    return m_journal.isEmpty() ? m_nextSeq : m_journal.first().seq;
}

void GameplayEventBus::setAuditRetention(int cap)
{
    if (cap == m_auditRetention) return;
    m_auditRetention = cap;
    if (m_auditRetention > 0 && m_auditLog.size() > m_auditRetention)
        m_auditLog.remove(0, m_auditLog.size() - m_auditRetention);
    emit auditRetentionChanged();
    emit eventCountChanged(); // rafraîchit auditCount
}

QVariantList GameplayEventBus::recentEvents(int max) const
{
    QVariantList out;
    if (max <= 0) return out;
    const int n     = m_journal.size();
    const int start = (n > max) ? (n - max) : 0;
    out.reserve(n - start);
    for (int i = start; i < n; ++i)
        out.append(m_journal.at(i).toVariantMap());
    return out;
}

// ---- D2 : curseur de reprise + noyau d'audit ------------------------------

QVariantMap GameplayEventBus::eventsSince(quint64 cursor, int max) const
{
    if (max <= 0) max = 256;

    const quint64 head   = m_nextSeq - 1;
    const quint64 oldest = oldestSeq();

    // Décrochage : le curseur pointe avant le plus ancien encore disponible →
    // le différentiel est incomplet, le consommateur doit re-snapshoter (Q-E06).
    const bool truncated = (cursor + 1 < oldest);

    QVariantList events;
    quint64 nextCursor = cursor;
    for (const meow::GameplayEvent &ev : m_journal) {
        if (ev.seq <= cursor) continue;
        events.append(ev.toVariantMap());
        nextCursor = ev.seq;
        if (events.size() >= max) break;
    }

    QVariantMap out;
    out.insert(QStringLiteral("events"), events);
    out.insert(QStringLiteral("count"), events.size());
    out.insert(QStringLiteral("nextCursor"), nextCursor);
    out.insert(QStringLiteral("head"), head);
    out.insert(QStringLiteral("oldestSeq"), oldest);
    out.insert(QStringLiteral("truncated"), truncated);
    return out;
}

QVariantMap GameplayEventBus::extractAuditCore(const meow::GameplayEvent &ev)
{
    // Champs du noyau d'audit D11, extraits du payload s'ils y figurent. Tant
    // que la couche proposition/arbitrage (Phase 2) ne les émet pas, ils
    // restent absents — la structure est prête sans invention de données.
    static const char *const k_keys[] = {
        "proposition", "verdict", "reasons", "amendment", "appliedVersion",
    };
    QVariantMap core;
    for (const char *k : k_keys) {
        const QString key = QString::fromLatin1(k);
        if (ev.payload.contains(key))
            core.insert(key, ev.payload.value(key));
    }
    return core;
}

QVariantList GameplayEventBus::auditLog(quint64 sinceSeq, int max) const
{
    QVariantList out;
    if (max <= 0) max = 256;
    for (const meow::GameplayEvent &ev : m_auditLog) {
        if (ev.seq <= sinceSeq) continue;
        QVariantMap m = ev.toVariantMap();
        m.insert(QStringLiteral("audit"), extractAuditCore(ev));
        out.append(m);
        if (out.size() >= max) break;
    }
    return out;
}

// ---- D4 : projection au schéma canal IA (Q-E06) ---------------------------
//
// Le canal expose au proposant/arbitre une vue CURÉE du journal, distincte de
// la projection brute toVariantMap() : une taxonomie de types orientée gameplay
// ("tile.placed", "proposal.verdict"…), une phrase courte, les uuids touchés, et
// un horodatage ISO-8601. Le schéma est figé par le manifeste (eventSummary).

QString GameplayEventBus::canalTypeName(meow::EventType type)
{
    switch (type) {
    case meow::EventType::GameStarted:          return QStringLiteral("game.started");
    case meow::EventType::MapLoaded:            return QStringLiteral("map.loaded");
    case meow::EventType::MapCleared:           return QStringLiteral("map.cleared");
    case meow::EventType::TileRemovedGame:      return QStringLiteral("tile.removed");
    case meow::EventType::MapRestored:          return QStringLiteral("map.restored");
    case meow::EventType::EditorOpLocal:        return QStringLiteral("editor.op");
    case meow::EventType::EditorOpRemote:       return QStringLiteral("editor.op");
    case meow::EventType::TileCreated:          return QStringLiteral("tile.placed");
    case meow::EventType::TileDeleted:          return QStringLiteral("tile.removed");
    case meow::EventType::TileMoved:            return QStringLiteral("tile.moved");
    case meow::EventType::ZoneParameterChanged: return QStringLiteral("zone.changed");
    case meow::EventType::CombatRequest:        return QStringLiteral("combat.request");
    case meow::EventType::CombatResolved:       return QStringLiteral("combat.resolved");
    case meow::EventType::Unknown:              break;
    }
    return QStringLiteral("unknown");
}

bool GameplayEventBus::canalVisibleTo(const QString &canalType, int audience)
{
    // Types réservés à l'arbitre (propositions en file, amendements) : non
    // encore émis avant la couche proposition (Phase 2), mais le filtre existe
    // pour que le proposant ne les voie jamais quand ils apparaîtront (Q-E06).
    static const QSet<QString> arbiterOnly = {
        QStringLiteral("proposal.queued"),
        QStringLiteral("proposal.amended"),
    };
    if (audience == AudienceArbiter)
        return true;                       // l'arbitre voit tout (public + réservé)
    return !arbiterOnly.contains(canalType); // le proposant ne voit que le public
}

bool GameplayEventBus::canalRelevant(const QString &canalType)
{
    // Types pertinents du résumé injecté (manifeste eventSummary.relevantTypes,
    // D44). proposal.verdict / memory.changed / rules.changed n'existent pas
    // encore (Phase 2) — inclus par anticipation pour ne pas re-toucher ce point.
    static const QSet<QString> relevant = {
        QStringLiteral("tile.placed"),
        QStringLiteral("proposal.verdict"),
        QStringLiteral("memory.changed"),
        QStringLiteral("rules.changed"),
    };
    return relevant.contains(canalType);
}

QStringList GameplayEventBus::canalRefsOf(const meow::GameplayEvent &ev)
{
    QStringList refs;
    for (const char *k : { "tileId", "target", "uuid" }) {
        const QString key = QString::fromLatin1(k);
        if (ev.payload.contains(key)) {
            const QString v = ev.payload.value(key).toString();
            if (!v.isEmpty() && !refs.contains(v))
                refs.append(v);
        }
    }
    return refs;
}

QString GameplayEventBus::canalPhraseOf(const meow::GameplayEvent &ev)
{
    switch (ev.type) {
    case meow::EventType::GameStarted:          return QStringLiteral("partie démarrée");
    case meow::EventType::MapLoaded:            return QStringLiteral("carte chargée");
    case meow::EventType::MapCleared:           return QStringLiteral("carte vidée");
    case meow::EventType::TileRemovedGame:      return QStringLiteral("tuile retirée");
    case meow::EventType::MapRestored: {
        const int n = ev.payload.value(QStringLiteral("count")).toInt();
        return QStringLiteral("carte restaurée (%1 tuiles)").arg(n);
    }
    case meow::EventType::EditorOpLocal:
    case meow::EventType::EditorOpRemote: {
        // Le payload porte l'op sous "op" ; on tente d'en extraire le type.
        const QVariantMap op = ev.payload.value(QStringLiteral("op")).toMap();
        const QString opType = op.value(QStringLiteral("type")).toString();
        return opType.isEmpty() ? QStringLiteral("opération d'éditeur")
                                : QStringLiteral("op d'éditeur : %1").arg(opType);
    }
    case meow::EventType::TileCreated:          return QStringLiteral("tuile posée");
    case meow::EventType::TileDeleted:          return QStringLiteral("tuile supprimée");
    case meow::EventType::TileMoved:            return QStringLiteral("tuile déplacée");
    case meow::EventType::ZoneParameterChanged: return QStringLiteral("paramètre de zone modifié");
    case meow::EventType::CombatRequest:        return QStringLiteral("demande de combat");
    case meow::EventType::CombatResolved:       return QStringLiteral("combat résolu");
    case meow::EventType::Unknown:              break;
    }
    return meow::eventTypeName(ev.type);
}

QVariantMap GameplayEventBus::canalEntryOf(const meow::GameplayEvent &ev)
{
    QVariantMap e;
    e.insert(QStringLiteral("seq"), ev.seq);
    e.insert(QStringLiteral("ts"),
             ev.wallTs > 0
                 ? QDateTime::fromMSecsSinceEpoch(ev.wallTs, QTimeZone::UTC)
                       .toString(Qt::ISODateWithMs)
                 : QString());
    e.insert(QStringLiteral("type"), canalTypeName(ev.type));
    e.insert(QStringLiteral("actor"), ev.author);
    e.insert(QStringLiteral("summary"), canalPhraseOf(ev));
    const QStringList refs = canalRefsOf(ev);
    e.insert(QStringLiteral("refs"), QVariant(refs));
    return e;
}

QVariantMap GameplayEventBus::canalPoll(quint64 cursor, int audience, int max) const
{
    if (max <= 0) max = 256;

    const quint64 oldest = oldestSeq();
    // Décrochage : le curseur pointe avant le plus ancien encore conservé → le
    // différentiel est incomplet, l'agent doit resynchroniser via state_query
    // plutôt que rejouer l'historique (Q-E06).
    const bool truncated = (cursor + 1 < oldest);

    QVariantList entries;
    quint64 nextCursor = cursor;
    for (const meow::GameplayEvent &ev : m_journal) {
        if (ev.seq <= cursor) continue;
        const QString type = canalTypeName(ev.type);
        if (!canalVisibleTo(type, audience)) {
            nextCursor = ev.seq; // consommé (filtré), le curseur avance quand même
            continue;
        }
        entries.append(canalEntryOf(ev));
        nextCursor = ev.seq;
        if (entries.size() >= max) break;
    }

    QVariantMap out;
    out.insert(QStringLiteral("entries"), entries);
    out.insert(QStringLiteral("count"), entries.size());
    out.insert(QStringLiteral("nextCursor"), nextCursor);
    out.insert(QStringLiteral("truncated"), truncated);
    out.insert(QStringLiteral("oldestSeq"), oldest);
    return out;
}

QVariantMap GameplayEventBus::canalSummary(quint64 cursor, int audience, int maxLines) const
{
    if (maxLines <= 0) maxLines = 250;

    const quint64 head   = m_nextSeq - 1;
    const quint64 oldest = oldestSeq();
    const bool truncated = (cursor + 1 < oldest);

    // Comptages par catégorie pertinente (manifeste injectedBlock.shape).
    int tilesPlaced = 0;
    QHash<QString, int> tilesByActor;
    int verdicts = 0, verdictsAccepted = 0, verdictsRejected = 0;
    int stateChanges = 0;
    int matched = 0;
    quint64 nextCursor = cursor;

    QStringList lines; // lignes détaillées (une par événement pertinent)
    for (const meow::GameplayEvent &ev : m_journal) {
        if (ev.seq <= cursor) continue;
        nextCursor = ev.seq;
        const QString type = canalTypeName(ev.type);
        if (!canalVisibleTo(type, audience)) continue;
        if (!canalRelevant(type)) continue;

        ++matched;
        if (type == QLatin1String("tile.placed")) {
            ++tilesPlaced;
            tilesByActor[ev.author.isEmpty() ? QStringLiteral("?") : ev.author]++;
        } else if (type == QLatin1String("proposal.verdict")) {
            ++verdicts;
            const QString v = ev.payload.value(QStringLiteral("verdict")).toString();
            if (v == QLatin1String("accepted"))      ++verdictsAccepted;
            else if (v == QLatin1String("rejected")) ++verdictsRejected;
        } else { // memory.changed / rules.changed
            ++stateChanges;
        }

        if (lines.size() < maxLines) {
            const QStringList refs = canalRefsOf(ev);
            QString line = QStringLiteral("  #%1 %2 · %3 · %4")
                               .arg(ev.seq)
                               .arg(type, ev.author, canalPhraseOf(ev));
            if (!refs.isEmpty())
                line += QStringLiteral(" [%1]").arg(refs.join(QStringLiteral(", ")));
            lines.append(line);
        }
    }

    const quint64 fromSeq = cursor + 1;
    const int omitted = matched - lines.size();

    // En-tête compact (manifeste injectedBlock.shape).
    QString headline;
    if (matched == 0) {
        headline = QStringLiteral("Depuis ton dernier tour (seq %1→%2) : rien de notable.")
                       .arg(fromSeq).arg(head);
    } else {
        QStringList byActor;
        for (auto it = tilesByActor.cbegin(); it != tilesByActor.cend(); ++it)
            byActor.append(QStringLiteral("%1×%2").arg(it.value()).arg(it.key()));
        headline = QStringLiteral(
            "Depuis ton dernier tour (seq %1→%2) : %3 tuiles posées%4, "
            "%5 verdicts (%6 acceptés / %7 rejetés), %8 changements d'état pertinents.")
            .arg(fromSeq).arg(head)
            .arg(tilesPlaced)
            .arg(byActor.isEmpty() ? QString()
                                   : QStringLiteral(" (%1)").arg(byActor.join(QStringLiteral(", "))))
            .arg(verdicts).arg(verdictsAccepted).arg(verdictsRejected)
            .arg(stateChanges);
    }

    QString text = headline;
    if (!lines.isEmpty())
        text += QLatin1Char('\n') + lines.join(QLatin1Char('\n'));
    if (omitted > 0)
        text += QStringLiteral("\n  + %1 événements omis — events_poll(%2)")
                    .arg(omitted).arg(cursor);
    if (truncated)
        text += QStringLiteral("\n  (journal tronqué en deçà du curseur — "
                               "resynchronise via state_query)");

    QVariantMap out;
    out.insert(QStringLiteral("text"), text);
    out.insert(QStringLiteral("fromSeq"), fromSeq);
    out.insert(QStringLiteral("toSeq"), head);
    out.insert(QStringLiteral("matched"), matched);
    out.insert(QStringLiteral("listed"), lines.size());
    out.insert(QStringLiteral("omitted"), omitted);
    out.insert(QStringLiteral("nextCursor"), nextCursor);
    out.insert(QStringLiteral("truncated"), truncated);
    out.insert(QStringLiteral("oldestSeq"), oldest);
    return out;
}

// ---- Ingestion : câblage des sources --------------------------------------

void GameplayEventBus::connectSources()
{
    if (m_sourcesConnected) return;
    m_sourcesConnected = true;
    connectGame();
    connectEditorOps();
    connectTiles();
    connectPhysics();
}

void GameplayEventBus::connectGame()
{
    Game *g = Game::instance();
    if (!g) return;

    connect(g, &Game::gameStarted, this, [this]() {
        publish(static_cast<int>(meow::EventType::GameStarted),
                static_cast<int>(meow::EventSource::Game),
                QStringLiteral("system"));
    });
    connect(g, &Game::clearCurrentMap, this, [this]() {
        publish(static_cast<int>(meow::EventType::MapCleared),
                static_cast<int>(meow::EventSource::Game),
                QStringLiteral("system"));
    });
    connect(g, &Game::mapLoaded, this, [this](Map *) {
        publish(static_cast<int>(meow::EventType::MapLoaded),
                static_cast<int>(meow::EventSource::Game),
                QStringLiteral("system"));
    });
    connect(g, &Game::tileRemoved, this, [this](QUuid tileId) {
        QVariantMap p;
        p.insert(QStringLiteral("tileId"),
                 tileId.toString(QUuid::WithoutBraces));
        publish(static_cast<int>(meow::EventType::TileRemovedGame),
                static_cast<int>(meow::EventSource::Game),
                QStringLiteral("local"), p);
    });
    connect(g, &Game::afterRestoration, this, [this](const QList<QUuid> &ids) {
        QVariantMap p;
        p.insert(QStringLiteral("count"), ids.size());
        publish(static_cast<int>(meow::EventType::MapRestored),
                static_cast<int>(meow::EventSource::Game),
                QStringLiteral("local"), p);
    });
}

void GameplayEventBus::connectEditorOps()
{
    EditorOpBus *bus = EditorOpBus::instance();
    if (!bus) return;

    connect(bus, &EditorOpBus::opRecorded, this, [this](const QJsonObject &op) {
        QVariantMap p;
        p.insert(QStringLiteral("op"), op.toVariantMap());
        publish(static_cast<int>(meow::EventType::EditorOpLocal),
                static_cast<int>(meow::EventSource::EditorOps),
                QStringLiteral("local"), p);
    });
    connect(bus, &EditorOpBus::remoteOpReceived, this, [this](const QJsonObject &op) {
        QVariantMap p;
        p.insert(QStringLiteral("op"), op.toVariantMap());
        publish(static_cast<int>(meow::EventType::EditorOpRemote),
                static_cast<int>(meow::EventSource::EditorOps),
                QStringLiteral("remote"), p);
    });
}

void GameplayEventBus::connectTiles()
{
    ItemSnapableEvents *evs = ItemSnapableEvents::instance();
    if (!evs) return;

    auto tileId = [](ItemSnapable *t) -> QString {
        return t ? t->uniqueId().toString(QUuid::WithoutBraces) : QString();
    };

    connect(evs, &ItemSnapableEvents::tileCreated, this, [this, tileId](ItemSnapable *t) {
        QVariantMap p;
        p.insert(QStringLiteral("tileId"), tileId(t));
        publish(static_cast<int>(meow::EventType::TileCreated),
                static_cast<int>(meow::EventSource::Tiles),
                QStringLiteral("local"), p);
    });
    connect(evs, &ItemSnapableEvents::tileDeleted, this,
            [this](const QUuid &id, int tileType) {
        QVariantMap p;
        p.insert(QStringLiteral("tileId"), id.toString(QUuid::WithoutBraces));
        p.insert(QStringLiteral("tileType"), tileType);
        publish(static_cast<int>(meow::EventType::TileDeleted),
                static_cast<int>(meow::EventSource::Tiles),
                QStringLiteral("local"), p);
    });
    connect(evs, &ItemSnapableEvents::tileMoved, this, [this, tileId](ItemSnapable *t) {
        QVariantMap p;
        p.insert(QStringLiteral("tileId"), tileId(t));
        publish(static_cast<int>(meow::EventType::TileMoved),
                static_cast<int>(meow::EventSource::Tiles),
                QStringLiteral("local"), p);
    });
    connect(evs, &ItemSnapableEvents::zoneParameterChanged, this,
            [this, tileId](ItemSnapable *t) {
        QVariantMap p;
        p.insert(QStringLiteral("tileId"), tileId(t));
        publish(static_cast<int>(meow::EventType::ZoneParameterChanged),
                static_cast<int>(meow::EventSource::Tiles),
                QStringLiteral("local"), p);
    });
}

void GameplayEventBus::connectPhysics()
{
    PhysicsSession *ps = PhysicsSession::instance();
    if (!ps) return;

    // PhysicsSession vit sur le thread GUI (comme le bus), mais la simulation
    // Pattounx tourne dans un worker dédié. On câble en QueuedConnection par
    // prudence : si un jour un signal physique était réémis depuis le worker,
    // l'ingestion resterait sûre (marshalling sur le thread du bus).
    connect(ps, &PhysicsSession::combatRequestReceived, this,
            [this](const QString &senderId, const QVariantMap &payload) {
        publish(static_cast<int>(meow::EventType::CombatRequest),
                static_cast<int>(meow::EventSource::Physics),
                senderId.isEmpty() ? QStringLiteral("remote") : senderId,
                payload);
    }, Qt::QueuedConnection);
    connect(ps, &PhysicsSession::combatEventReceived, this,
            [this](const QVariantMap &payload) {
        publish(static_cast<int>(meow::EventType::CombatResolved),
                static_cast<int>(meow::EventSource::Physics),
                QStringLiteral("host"), payload);
    }, Qt::QueuedConnection);
}

// ==================== Enregistrement ====================
//
// D4 : l'enregistrement formel du singleton est désormais porté par
// `qmlapp.cpp` (au branchement du canal IA), aux côtés des autres
// `registerQml()`. Le bus n'utilise plus le bootstrap
// `Q_COREAPP_STARTUP_FUNCTION` de D1 : `QmlApp` appelle `registerQml()` puis
// diffère `connectSources()` à l'event loop (après instanciation des singletons
// sources Game / EditorOpBus / ItemSnapableEvents / PhysicsSession).
