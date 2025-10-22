#ifndef ANIMATIONPROVIDER_H
#define ANIMATIONPROVIDER_H

#include <QObject>
#include <QQmlEngine>
#include <QImage>
#include <QTimer>

class AnimationProvider : public QObject
{
    Q_OBJECT

    QList<QImage*> m_images;

public:
    static void registerQml();
    static AnimationProvider *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);


    void loadImagesFromFolder(const QString &folderPath);
    QList<QImage*> images() const;

    QTimer *m_timer;
    int m_currentFrame;
public slots:

signals:
    void frameChanged(const QImage *imageData);

private slots:

private:
    explicit AnimationProvider(QObject *parent = nullptr);
    static AnimationProvider *m_pThis;

    void imagesChanged();
    void updateImage();
};

#endif // ANIMATIONPROVIDER_H
