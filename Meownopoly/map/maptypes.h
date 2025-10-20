#ifndef MAPTYPES_H
#define MAPTYPES_H

#include <QObject>

namespace MapTypes {
    Q_NAMESPACE
    enum MapType {
        AUTOSAVE,
        CUSTOM,
        UNDOREDO
    };
    Q_ENUM_NS(MapType)
}

#endif // MAPTYPES_H
