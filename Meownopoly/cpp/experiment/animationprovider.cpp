#include "animationprovider.h"
#include "qdir.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>

AnimationProvider *AnimationProvider::m_pThis = nullptr;

AnimationProvider::AnimationProvider(QObject *parent)
    : QObject(parent)
    , m_timer(new QTimer(this))
{
    m_timer->setInterval(1000 / 120);
    connect(m_timer, &QTimer::timeout, this, &AnimationProvider::updateImage);
    m_timer->start();
}

void AnimationProvider::registerQml()
{
    qmlRegisterSingletonType<AnimationProvider>("AnimationProvider",
                                                1,
                                                0,
                                                "AnimationProvider",
                                                &AnimationProvider::qmlInstance);
}

AnimationProvider *AnimationProvider::instance()
{
    if (m_pThis == nullptr) // avoid creation of new instances
    {
        m_pThis = new AnimationProvider;
    }
    return m_pThis;
}

QObject *AnimationProvider::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);
    // C++ and QML instance they are the same instance
    return AnimationProvider::instance();
}

void AnimationProvider::updateImage()
{
    if (m_images.empty())
        return;
    m_currentFrame = (m_currentFrame + 1) % m_images.size();
    emit frameChanged(m_images[m_currentFrame]);
}

QList<QImage*> AnimationProvider::images() const
{
    return m_images;
}

void AnimationProvider::imagesChanged()
{
    if (m_images.empty())
        return;
    emit frameChanged(m_images[m_currentFrame]);
}

void AnimationProvider::loadImagesFromFolder(const QString &folderPath)
{
    QDir dir(folderPath);
    QStringList filters;
    filters << "*.png" << "*.jpg" << "*.jpeg";
    dir.setNameFilters(filters);
    dir.setSorting(QDir::Name);
    m_currentFrame = 0;
    QStringList images = dir.entryList(QDir::Files);
    for (const QString &image : images) {
        m_images.append(new QImage(dir.absoluteFilePath(image)));
        qDebug() << "AnimationProvider: Loaded image" << dir.absoluteFilePath(image);
    }
    imagesChanged();
}
