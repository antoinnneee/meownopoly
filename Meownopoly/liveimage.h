#ifndef LIVEIMAGE_H
#define LIVEIMAGE_H

#include <QImage>
#include <QQuickPaintedItem>
#include <QPainter>
#include "animationprovider.h"

class LiveImage : public QQuickPaintedItem
{
    Q_OBJECT

    // Just storage for the image
    const QImage *m_image = nullptr;

public:
    explicit LiveImage(QQuickItem *parent = nullptr);
    void setImage(const QImage *image);
    void paint(QPainter *painter) override;
    AnimationProvider *m_animationProvider;
};

#endif // LIVEIMAGE_H
