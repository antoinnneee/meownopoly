#ifndef EDITOR_OP_TYPE_H
#define EDITOR_OP_TYPE_H

#include <QObject>

/// Types d'opérations d'édition du protocole collaboratif.
/// Chaque op est un QJsonObject de la forme :
///   { "op": <type>, "target": "<uuid>", ...payload fields }
/// Les valeurs sont exposées à QML via EditorOpBus.OP_*.
namespace EditorOpType {
Q_NAMESPACE

enum Value : quint8 {
    // Création / suppression
    CreateItem              = 1,   // payload: "item" (ItemSnapable JSON complet, UUID pré-mintée)
    DeleteItem              = 2,   // target: uuid

    // Déplacement / taille
    MoveItem                = 3,   // target: uuid, gridX, gridY, zOrder
    ResizeItem              = 4,   // target: uuid, w, h

    // Édition de propriétés typées
    SetDisplayParameter     = 5,   // target: uuid, fields: {...}
    SetCaseData             = 6,   // target: uuid, fields: {...}
    SetDecorationParameter  = 7,   // target: uuid, fields: {...}
    SetZoneParameter        = 8,   // target: uuid, fields: {...}

    // Connexions / liens
    LinkItems               = 9,   // source: uuid, target: uuid, kind: "next"|"prev"
    UnlinkItems             = 10,  // source: uuid, target: uuid, kind: "next"|"prev"

    // Transport générique d'un EditDelta complet (Map::applyDelta côté peer).
    // Payload: { type, tileId, groupId, before, after, applyBefore }
    // Utilisé par Game::updateMap et Game::askPreview/askNext pour la sync
    // bi-directionnelle sans décomposer les mutations en ops fines.
    ApplyState              = 11,

    // Player config panel (PCP_*) — roster de PlayerProfile sur MapInfo.
    AddPlayerProfile        = 12,  // payload: { profile: {id, name, modelName, pickMode, minOccurrences, ...} }
    RemovePlayerProfile     = 13,  // payload: { id }
    UpdatePlayerProfile     = 14,  // payload: { id, fields: {...} }  // partial
    ReorderPlayerProfile    = 15,  // payload: { id, newIndex }
    SetMapPlayerLimits      = 16,  // payload: { minPlayers?, maxPlayers? }
};
Q_ENUM_NS(Value)

}

#endif // EDITOR_OP_TYPE_H
