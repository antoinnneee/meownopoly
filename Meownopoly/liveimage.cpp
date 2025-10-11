#include "LiveImage.h"
#include "animationprovider.h"

LiveImage::LiveImage(QQuickItem *parent) : QQuickPaintedItem(parent), m_image{}
{
    m_animationProvider = AnimationProvider::instance();
    connect(m_animationProvider, &AnimationProvider::frameChanged, this, &LiveImage::setImage, Qt::DirectConnection);

}

void LiveImage::paint(QPainter *painter)
{
    disconnect(m_animationProvider, &AnimationProvider::frameChanged, this, &LiveImage::setImage);

    if (m_image)
        painter->drawImage(0, 0, *m_image);
    connect(m_animationProvider, &AnimationProvider::frameChanged, this, &LiveImage::setImage, Qt::DirectConnection);
}

void LiveImage::setImage(const QImage *image)
{
    // Update the image
    m_image = image;
    // Redraw the image
    update();
}
