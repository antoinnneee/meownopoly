#ifndef CHAT_IMAGE_PROVIDER_H
#define CHAT_IMAGE_PROVIDER_H

#include <QQuickImageProvider>
#include <QImage>
#include <QHash>
#include <QMutex>

class ChatImageProvider : public QQuickImageProvider
{
public:
    ChatImageProvider();
    
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
    
    static QString addImage(const QImage &image);
    static QImage getImage(const QString &id);
    static void clear();

private:
    static QHash<QString, QImage> m_images;
    static QMutex m_mutex;
};

#endif // CHAT_IMAGE_PROVIDER_H
