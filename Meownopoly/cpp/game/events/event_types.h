/*
 *      V3 Piste D — Types du journal d'événements métier
 *
 * Définit `GameplayEvent`, l'unité du journal consommé par le canal IA
 * (résumé injecté à l'invocation + tool `events_poll(cursor)`, cf.
 * doc/v3/02_CANAL_IA.md §4) et par le noyau d'audit (décision D19,
 * doc/v3/08). La source de l'événement porte l'autorité (D33).
 *
 * Contrainte de linkabilité : ce header ne dépend QUE de QtCore — aucun
 * include réseau (Catway/chat/EditorSession) ni QML, pour rester liable
 * dans le banc headless (meow_testbench) comme dans le jeu complet.
 */
#ifndef GAMEPLAY_EVENT_TYPES_H
#define GAMEPLAY_EVENT_TYPES_H

#include <QDateTime>
#include <QJsonObject>
#include <QMetaType>
#include <QString>
#include <QUuid>

// Source émettrice d'un événement (D33 : l'autorité d'un événement dépend
// de sa source, pas de son type). Sérialisée en string stable dans le JSON.
enum class GameplayEventSource : quint8 {
    Editor = 0,   // mutations d'édition (tuiles, zones, paramètres)
    Game,         // cycle de vie de la partie / de la map
    Physics,      // événements issus du moteur/de la session physique
    Memory,       // espace mémoire (doc 05) — réservé, pas encore branché
    Proposal,     // cycle de vie des propositions IA (doc 13) — réservé
    System,       // bus lui-même, diagnostics, événements internes
};

// Un événement métier du journal. `seq` est attribué par le bus à l'append
// (monotone, jamais réutilisé) ; le producteur ne le remplit pas.
struct GameplayEvent
{
    quint64             seq = 0;        // séquence monotone (attribuée par le bus)
    QUuid               id;             // identité stable (créée par le bus si nulle)
    QString             type;           // type stable, ex. "tile.created", "map.loaded"
    QString             author;         // playerId auteur ; vide = local/système
    GameplayEventSource source = GameplayEventSource::System;
    qint64              lamportTs = 0;  // horloge logique (attribuée par le bus)
    qint64              wallTs = 0;     // ms epoch (attribué par le bus si 0)
    QJsonObject         payload;        // charge utile compacte, spécifique au type
    bool                durable = false; // true = noyau d'audit D19 (non tronqué par le ring)

    // ── Sérialisation JSON (events_poll + persistance future) ──────────
    // Note : `seq`/`wallTs` passent par le double de QJsonValue — sans perte
    // tant que < 2^53, très largement suffisant ici.

    static QString sourceToString(GameplayEventSource s)
    {
        switch (s) {
        case GameplayEventSource::Editor:   return QStringLiteral("editor");
        case GameplayEventSource::Game:     return QStringLiteral("game");
        case GameplayEventSource::Physics:  return QStringLiteral("physics");
        case GameplayEventSource::Memory:   return QStringLiteral("memory");
        case GameplayEventSource::Proposal: return QStringLiteral("proposal");
        case GameplayEventSource::System:   return QStringLiteral("system");
        }
        return QStringLiteral("system");
    }

    static GameplayEventSource sourceFromString(const QString &s)
    {
        if (s == QLatin1String("editor"))   return GameplayEventSource::Editor;
        if (s == QLatin1String("game"))     return GameplayEventSource::Game;
        if (s == QLatin1String("physics"))  return GameplayEventSource::Physics;
        if (s == QLatin1String("memory"))   return GameplayEventSource::Memory;
        if (s == QLatin1String("proposal")) return GameplayEventSource::Proposal;
        return GameplayEventSource::System;
    }

    QJsonObject toJson() const
    {
        QJsonObject o;
        o[QStringLiteral("seq")]       = static_cast<double>(seq);
        o[QStringLiteral("id")]        = id.toString(QUuid::WithoutBraces);
        o[QStringLiteral("type")]      = type;
        o[QStringLiteral("author")]    = author;
        o[QStringLiteral("source")]    = sourceToString(source);
        o[QStringLiteral("lamportTs")] = static_cast<double>(lamportTs);
        o[QStringLiteral("wallTs")]    = static_cast<double>(wallTs);
        o[QStringLiteral("payload")]   = payload;
        o[QStringLiteral("durable")]   = durable;
        return o;
    }

    static GameplayEvent fromJson(const QJsonObject &o)
    {
        GameplayEvent ev;
        ev.seq       = static_cast<quint64>(o.value(QStringLiteral("seq")).toDouble());
        ev.id        = QUuid::fromString(o.value(QStringLiteral("id")).toString());
        ev.type      = o.value(QStringLiteral("type")).toString();
        ev.author    = o.value(QStringLiteral("author")).toString();
        ev.source    = sourceFromString(o.value(QStringLiteral("source")).toString());
        ev.lamportTs = static_cast<qint64>(o.value(QStringLiteral("lamportTs")).toDouble());
        ev.wallTs    = static_cast<qint64>(o.value(QStringLiteral("wallTs")).toDouble());
        ev.payload   = o.value(QStringLiteral("payload")).toObject();
        ev.durable   = o.value(QStringLiteral("durable")).toBool();
        return ev;
    }
};

// Nécessaire pour transporter GameplayEvent dans un signal en connexion
// queued (consommateur sur un autre thread). Enregistré au runtime dans
// GameplayEventBus::registerQml().
Q_DECLARE_METATYPE(GameplayEvent)

#endif // GAMEPLAY_EVENT_TYPES_H
