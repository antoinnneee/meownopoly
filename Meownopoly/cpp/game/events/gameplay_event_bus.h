/*
 *      V3 Piste D — GameplayEventBus (journal d'événements métier)
 *
 * Bus singleton qui journalise les événements métier (D1) et sert la
 * relecture par curseur (D2, schéma Q-E06 du doc 09) :
 *
 *  - `append(ev)` attribue une séquence monotone + horloge Lamport +
 *    horodatage mur, stocke dans un ring borné (MEOW_EVENTBUS_CAPACITY) ;
 *    les événements `durable` (noyau d'audit D19) vont AUSSI dans une
 *    liste d'audit non tronquée par le ring (bornée MEOW_EVENTBUS_AUDIT_MAX).
 *  - `eventsSince(cursor, max, durableOnly)` relit de façon idempotente ;
 *    si le curseur est plus vieux que ce que le store contient encore,
 *    `truncated=true` + `oldestSeq` signalent au client de repartir d'un
 *    snapshot (state_query), cf. Q-E06.
 *  - signal `eventAppended` pour le déclenchement de règles (D33) et
 *    l'injection IA future.
 *
 * Horloge Lamport : PAS de dépendance dure vers `Game` — l'horloge externe
 * est injectée par `setLamportProvider` (qmlapp branche une lecture de
 * `Game::lamportClock()`, cf. game_lamport.cpp). Le bus garantit la
 * monotonie locale via `max(externe, dernier + 1)` : on ne TICKE pas
 * l'horloge de Game (son tick pilote les zOrder et émet lamportClockChanged
 * — le faire par événement ferait churner les previews). Sans provider
 * (banc headless, tests), compteur local pur.
 *
 * Thread-safety : QMutex sur ring/audit/compteurs (PhysicsSession et de
 * futurs producteurs peuvent émettre hors GUI thread). `eventAppended` est
 * émis HORS mutex, en Qt::AutoConnection standard : livraison directe pour
 * les receveurs du thread appelant, queued sinon (GameplayEvent est
 * enregistré comme metatype dans registerQml). Le provider Lamport est
 * appelé sous mutex : il doit rester trivial (lecture d'un entier).
 *
 * Protection D12 (version minimale, D3 du plan) : garde de réentrance
 * thread-local — si un slot connecté en direct ré-appende pendant un
 * append, la profondeur de cascade est bornée par MEOW_EVENTBUS_MAX_CASCADE ;
 * au-delà : warning + drop tracé (append retourne 0).
 *
 * Linkabilité : ne dépend que de QtCore + QtQml (registerQml). Aucun
 * include réseau (Catway/chat/EditorSession) — liable dans le banc.
 */
#ifndef GAMEPLAY_EVENT_BUS_H
#define GAMEPLAY_EVENT_BUS_H

#include <QJsonObject>
#include <QMutex>
#include <QObject>
#include <QQmlEngine>

#include <deque>
#include <functional>

#include "event_types.h"

// Constantes de dimensionnement (pattern D22 : #define compile-time,
// surchargables par -D pour les tests / le banc).
#ifndef MEOW_EVENTBUS_CAPACITY
#define MEOW_EVENTBUS_CAPACITY 4096     // taille du ring (tous événements)
#endif
#ifndef MEOW_EVENTBUS_AUDIT_MAX
#define MEOW_EVENTBUS_AUDIT_MAX 65536   // borne dure de la liste d'audit (durable)
#endif
#ifndef MEOW_EVENTBUS_MAX_CASCADE
#define MEOW_EVENTBUS_MAX_CASCADE 8     // profondeur max d'appends réentrants
#endif

class GameplayEventBus : public QObject
{
    Q_OBJECT
public:
    static GameplayEventBus *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);
    static void registerQml();

    // Injecte la lecture de l'horloge Lamport externe (ex. Game::lamportClock).
    // Le callable est appelé sous le mutex du bus : il doit être trivial et
    // thread-safe (lecture d'un entier). nullptr = compteur local pur.
    void setLamportProvider(std::function<qint64()> provider);

    // Journalise un événement. Attribue seq/id/lamportTs/wallTs (les champs
    // laissés à 0/nul par le producteur). Retourne la séquence attribuée,
    // ou 0 si l'événement a été droppé par la garde de cascade.
    quint64 append(GameplayEvent ev);

    // Relecture par curseur (idempotente) : événements de seq > cursor,
    // au plus maxCount (<=0 → défaut 256). durableOnly=true lit la liste
    // d'audit (D19) au lieu du ring. Retourne :
    //   { events: [...], truncated: bool, oldestSeq: n, nextCursor: n }
    // truncated=true ⇔ des événements entre cursor et oldestSeq ont été
    // perdus (ring recyclé / audit débordé) → le client doit repartir d'un
    // snapshot (schéma Q-E06).
    Q_INVOKABLE QJsonObject eventsSince(quint64 cursor, int maxCount = 256,
                                        bool durableOnly = false) const;

    // Dernière séquence attribuée (0 si journal vierge).
    Q_INVOKABLE quint64 lastSeq() const;

    // Compteur de drops par la garde de cascade (diagnostic).
    quint64 droppedCascadeCount() const;

    // Remise à zéro complète (tests / changement de partie). Ne ré-émet rien.
    Q_INVOKABLE void clear();

signals:
    // Émis après stockage, hors mutex. AutoConnection : direct si le
    // receveur est sur le thread de l'append, queued sinon.
    void eventAppended(const GameplayEvent &event);

private:
    explicit GameplayEventBus(QObject *parent = nullptr);
    static GameplayEventBus *m_instance;

    mutable QMutex            m_mutex;
    std::deque<GameplayEvent> m_ring;    // tous les événements, borné CAPACITY
    std::deque<GameplayEvent> m_audit;   // durables seulement, borné AUDIT_MAX
    quint64 m_nextSeq        = 1;        // prochaine séquence à attribuer
    qint64  m_lamport        = 0;        // dernier lamportTs attribué
    quint64 m_ringDroppedUpTo  = 0;      // seq du dernier événement recyclé du ring
    quint64 m_auditDroppedUpTo = 0;      // seq du dernier durable évincé de l'audit
    quint64 m_droppedCascade = 0;        // drops par la garde de réentrance
    bool    m_auditOverflowWarned = false;

    std::function<qint64()> m_lamportProvider;
};

#endif // GAMEPLAY_EVENT_BUS_H
