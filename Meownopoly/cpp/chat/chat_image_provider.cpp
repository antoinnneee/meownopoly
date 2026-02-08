#include "chat_image_provider.h"
#include <QUuid>

QHash<QString, QImage> ChatImageProvider::m_images;
QMutex ChatImageProvider::m_mutex;

ChatImageProvider::ChatImageProvider() 
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

QImage ChatImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    QMutexLocker locker(&m_mutex);
    QImage img = m_images.value(id);
    
    if (size)
        *size = img.size();
        
    if (requestedSize.width() > 0 && requestedSize.height() > 0)
        return img.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        
    return img;
}

QString ChatImageProvider::addImage(const QImage &image)
{
    QMutexLocker locker(&m_mutex);
    QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_images.insert(id, image);
    return id;
}

QImage ChatImageProvider::getImage(const QString &id)
{
    QMutexLocker locker(&m_mutex);
    return m_images.value(id);
}

void ChatImageProvider::clear()
{
    QMutexLocker locker(&m_mutex);
    m_images.clear();
}
