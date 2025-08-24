#ifndef ITEMSNAPABLE_H
#define ITEMSNAPABLE_H

#include <QObject>
#include <QQmlEngine>
#include <QUrl>
#include "case/Case.h"

class ItemSnapable : public QObject
{
    Q_OBJECT
public:
    ItemSnapable();

    static void registerQml();

private :


    int unitSizeWidth;
    int unitSizeHeight;
    int gridRelativePosition;
    int gridRelativePositionY;
    int zLayer;
    QUrl assetUrl;
};

#endif // ITEMSNAPABLE_H
