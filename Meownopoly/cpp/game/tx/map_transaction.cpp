#include "map_transaction.h"

#include "game/map/map.h"
#include "game/map/mapinfo.h"

#include <QJsonDocument>
#include <QSet>
#include <QDebug>

namespace MeowTx {

MapTransaction::MapTransaction(const QUuid &id) : m_id(id) {}

void MapTransaction::markFailed(const QString &reason)
{
    if (m_failed) return; // première cause conservée
    m_failed = true;
    m_failureReason = reason;
    qWarning().noquote() << "[MapTransaction]" << m_id.toString()
                         << "marquée en échec :" << reason;
}

void MapTransaction::recordApplied(const EditDelta &delta)
{
    m_deltas.append(delta);
}

QString MapTransaction::canonicalJson(const QJsonObject &obj)
{
    // QJsonObject maintient ses clés triées : la forme compacte est stable
    // pour un même contenu, quelle que soit l'origine (toJSON vs delta).
    return QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

// ── Phase prepare ────────────────────────────────────────────────────────────

bool MapTransaction::validateDelta(Map *map, const EditDelta &delta,
                                   QString *reasonOut)
{
    auto fail = [&](const QString &why) {
        if (reasonOut) *reasonOut = why;
        return false;
    };

    if (!map)
        return fail(QStringLiteral("map nulle"));

    switch (delta.type) {
    case EditDeltaType::TileModified:
        if (delta.tileId.isNull())
            return fail(QStringLiteral("TileModified sans tileId"));
        if (!map->tileById(delta.tileId))
            return fail(QStringLiteral("TileModified sur tuile absente %1")
                            .arg(delta.tileId.toString()));
        if (delta.after.isEmpty())
            return fail(QStringLiteral("TileModified avec `after` vide"));
        break;
    case EditDeltaType::TileAdded:
        if (delta.tileId.isNull())
            return fail(QStringLiteral("TileAdded sans tileId"));
        if (delta.after.isEmpty())
            return fail(QStringLiteral("TileAdded avec `after` vide"));
        // Tuile déjà présente : toléré (idempotence historique de updateMap —
        // le switch TileAdded skippe addTile si tileById non nul).
        break;
    case EditDeltaType::TileDeleted:
        if (delta.tileId.isNull())
            return fail(QStringLiteral("TileDeleted sans tileId"));
        if (!map->tileById(delta.tileId))
            return fail(QStringLiteral("TileDeleted sur tuile absente %1")
                            .arg(delta.tileId.toString()));
        break;
    case EditDeltaType::MetadataChanged:
        if (delta.after.isEmpty())
            return fail(QStringLiteral("MetadataChanged avec `after` vide"));
        break;
    }
    return true;
}

bool MapTransaction::prevalidateBatch(Map *map, const QList<EditDelta> &deltas,
                                      QString *reasonOut)
{
    auto fail = [&](int idx, const QString &why) {
        const QString msg = QStringLiteral("op %1/%2 invalide : %3")
                                .arg(idx + 1).arg(deltas.size()).arg(why);
        if (reasonOut) *reasonOut = msg;
        qWarning().noquote() << "[MapTransaction] prevalidateBatch —" << msg;
        return false;
    };

    if (!map) {
        if (reasonOut) *reasonOut = QStringLiteral("map nulle");
        return false;
    }

    // Simulation du write-set : existence des tuiles au fil du lot, sans
    // muter la Map. Une op Added rend la tuile « présente » pour les ops
    // suivantes du même lot ; une Deleted la rend « absente ».
    QSet<QUuid> added;
    QSet<QUuid> removed;
    auto exists = [&](const QUuid &id) {
        if (added.contains(id))   return true;
        if (removed.contains(id)) return false;
        return map->tileById(id) != nullptr;
    };

    for (int i = 0; i < deltas.size(); ++i) {
        const EditDelta &d = deltas.at(i);
        switch (d.type) {
        case EditDeltaType::TileModified:
            if (d.tileId.isNull())
                return fail(i, QStringLiteral("TileModified sans tileId"));
            if (!exists(d.tileId))
                return fail(i, QStringLiteral("TileModified sur tuile absente %1")
                                   .arg(d.tileId.toString()));
            if (d.after.isEmpty())
                return fail(i, QStringLiteral("TileModified avec `after` vide"));
            break;
        case EditDeltaType::TileAdded:
            if (d.tileId.isNull())
                return fail(i, QStringLiteral("TileAdded sans tileId"));
            if (d.after.isEmpty())
                return fail(i, QStringLiteral("TileAdded avec `after` vide"));
            if (exists(d.tileId))
                return fail(i, QStringLiteral("TileAdded sur tuile déjà présente %1")
                                   .arg(d.tileId.toString()));
            removed.remove(d.tileId);
            added.insert(d.tileId);
            break;
        case EditDeltaType::TileDeleted:
            if (d.tileId.isNull())
                return fail(i, QStringLiteral("TileDeleted sans tileId"));
            if (!exists(d.tileId))
                return fail(i, QStringLiteral("TileDeleted sur tuile absente %1")
                                   .arg(d.tileId.toString()));
            added.remove(d.tileId);
            removed.insert(d.tileId);
            break;
        case EditDeltaType::MetadataChanged:
            if (d.after.isEmpty())
                return fail(i, QStringLiteral("MetadataChanged avec `after` vide"));
            break;
        }
    }
    return true;
}

// ── Phase commit ─────────────────────────────────────────────────────────────

bool MapTransaction::verifyWriteSet(Map *map, QString *conflictOut) const
{
    auto conflict = [&](const QString &why) {
        if (conflictOut) *conflictOut = why;
        qWarning().noquote() << "[MapTransaction]" << m_id.toString()
                             << "conflit write-set :" << why;
        return false;
    };

    if (!map)
        return conflict(QStringLiteral("map nulle au commit"));

    // État final attendu par tuile : dernier delta gagne.
    struct Expected { bool present; QJsonObject state; };
    QHash<QUuid, Expected> expected;
    bool metadataTouched = false;
    QJsonObject expectedMetadata;

    for (const EditDelta &d : m_deltas) {
        switch (d.type) {
        case EditDeltaType::TileModified:
        case EditDeltaType::TileAdded:
            expected.insert(d.tileId, { true, d.after });
            break;
        case EditDeltaType::TileDeleted:
            expected.insert(d.tileId, { false, {} });
            break;
        case EditDeltaType::MetadataChanged:
            metadataTouched = true;
            expectedMetadata = d.after;
            break;
        }
    }

    for (auto it = expected.constBegin(); it != expected.constEnd(); ++it) {
        ItemSnapable *tile = map->tileById(it.key());
        if (!it.value().present) {
            if (tile)
                return conflict(QStringLiteral("tuile %1 supprimée par la "
                                               "transaction mais présente sur la map")
                                    .arg(it.key().toString()));
            continue;
        }
        if (!tile)
            return conflict(QStringLiteral("tuile %1 touchée par la transaction "
                                           "mais absente de la map (mutation concurrente ?)")
                                .arg(it.key().toString()));

        // Provenance : dans la voie fil-de-l'eau, `after` sort de
        // tile->toJSON() au moment du recordApplied — la comparaison avec le
        // toJSON() courant est donc à sérialiseur identique (pas de faux
        // conflit de format). Tout futur applicateur (propositions V3) doit
        // conserver cette provenance.
        const QJsonObject current =
            QJsonDocument::fromJson(tile->toJSON().toUtf8()).object();
        if (canonicalJson(current) != canonicalJson(it.value().state))
            return conflict(QStringLiteral("tuile %1 modifiée concurremment "
                                           "depuis l'application de la transaction")
                                .arg(it.key().toString()));
    }

    if (metadataTouched) {
        MapInfo *mi = map->getMapInfo();
        if (!mi)
            return conflict(QStringLiteral("mapInfo absente au commit"));
        const QJsonObject current =
            QJsonDocument::fromJson(mi->toJSON().toUtf8()).object();
        // Normalisation par round-trip MapInfo : le `after` du delta peut ne
        // pas être passé par le sérialiseur (champs par défaut, formats de
        // nombres) — on compare deux sorties du MÊME toJSON pour éviter les
        // faux conflits.
        MapInfo normalized(expectedMetadata);
        const QJsonObject expectedCanon =
            QJsonDocument::fromJson(normalized.toJSON().toUtf8()).object();
        if (canonicalJson(current) != canonicalJson(expectedCanon))
            return conflict(QStringLiteral("mapInfo modifiée concurremment "
                                           "depuis l'application de la transaction"));
    }
    return true;
}

// ── Phase rollback ───────────────────────────────────────────────────────────

void MapTransaction::rollback(Map *map, QList<QUuid> *touchedOut)
{
    if (!map || m_deltas.isEmpty())
        return;

    qWarning().noquote() << "[MapTransaction] rollback" << m_id.toString()
                         << "—" << m_deltas.size() << "delta(s) inversé(s)";

    QSet<QUuid> touched;
    // Inverses `before` en ordre inverse d'application (dernier appliqué,
    // premier annulé). applyDelta(applyBefore=true) est le même moteur que
    // Map::undo : restauration + rewire des liens + commitCurrentState.
    for (auto it = m_deltas.crbegin(); it != m_deltas.crend(); ++it)
        map->applyDelta(*it, /*applyBefore=*/true, touched);

    m_deltas.clear();
    if (touchedOut) *touchedOut = touched.values();
}

} // namespace MeowTx
