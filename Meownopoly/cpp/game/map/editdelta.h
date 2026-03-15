#ifndef EDITDELTA_H
#define EDITDELTA_H

#include <QUuid>
#include <QJsonObject>
#include <QObject>

namespace EditDeltaType {
    Q_NAMESPACE
    enum Type {
        TileModified  = 0,
        TileAdded     = 1,
        TileDeleted   = 2,
        MetadataChanged = 3
    };
    Q_ENUM_NS(Type)
}

struct EditDelta {
    EditDeltaType::Type type = EditDeltaType::TileModified;
    QUuid               tileId;
    QUuid               groupId;    // null = atomique ; meme ID = groupe logique
    QJsonObject         before;     // {} si TileAdded
    QJsonObject         after;      // {} si TileDeleted
};

#endif // EDITDELTA_H
