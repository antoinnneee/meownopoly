/*
 *      Meownopoly V3 — réservation de la plage de types de messages réseau
 *
 * Cartographie des plages sur Catway (1er octet de chaque paquet) :
 *  - GameMessageType    (0x01–0x1F)
 *  - EditorMessageType  (0x20–0x3F)
 *  - PhysicsMessageType (0x40–0x5F)
 *  - V3MessageType      (0x60–0x7F)  ← ce fichier (plan doc/v3/15, P0-3)
 *
 * ⚠️ Les protocoles existants filtrent par plage (`isEditorPacket`,
 * `isPhysicsPacket`) : une valeur hors plage est droppée silencieusement.
 * Toute nouvelle valeur V3 doit rester dans 0x60–0x7F et être ajoutée au
 * sous-bloc de son protocole ci-dessous.
 *
 * Sous-blocs réservés (décisions D35/D40, chantiers M3/M4/M6/M10) :
 *  - 0x60–0x67 : ProposalSession (D40) — enveloppe de proposition, verdict,
 *                file, suspension (doc 13).
 *  - 0x68–0x6F : bus d'état runtime memory.state (D35/D39) — deltas coalescés,
 *                snapshots de réparation/structurel, RequestStateSnapshot.
 *  - 0x70–0x77 : transactions atomiques (M4) — TxPrepare/TxCommit/TxRollback/TxAck.
 *  - 0x78–0x7F : migration d'hôte V3 (M10, D37) — Checkpoint, CheckpointAck,
 *                SuspendProposals, NewAuthority.
 *
 * Les enums concrets seront ajoutés par chantier ; chaque message V3 porte en
 * plus, dans son enveloppe applicative (M3), son type de garantie :
 * commit (ACK + retry + dédup) ou état supersédable (séquence + réparation).
 */
#ifndef V3_MESSAGE_TYPE_H
#define V3_MESSAGE_TYPE_H

#include <QObject>

namespace V3MessageType {
Q_NAMESPACE

enum Value : quint8 {
    // Bornes de la plage V3 — utilisées par le futur `isV3Packet` (filtre par
    // plage, même patron que EditorProtocol/PhysicsProtocol).
    RangeFirst = 0x60,
    RangeLast  = 0x7F,
};
Q_ENUM_NS(Value)

/// Vrai si l'octet de type appartient à la plage réservée V3.
inline bool isV3Packet(quint8 type)
{
    return type >= RangeFirst && type <= RangeLast;
}

}

#endif // V3_MESSAGE_TYPE_H
