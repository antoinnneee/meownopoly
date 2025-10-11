#ifndef ANIMATION_MANAGER_H
#define ANIMATION_MANAGER_H

#include <QObject>
#include <QTimer>
#include <QImage>
#include <QStringList>
#include <QMap>

class AnimationManager : public QObject
{
    Q_OBJECT

public:
    explicit AnimationManager(QObject *parent = nullptr);
    ~AnimationManager();

    // Méthodes pour gérer les animations
    Q_INVOKABLE void loadAnimation(const QString &animationName, const QStringList &framePaths);
    Q_INVOKABLE void startAnimation(const QString &animationName, int frameRate = 30);
    Q_INVOKABLE void stopAnimation(const QString &animationName);
    Q_INVOKABLE void setCurrentFrame(const QString &animationName, int frameIndex);
    Q_INVOKABLE QImage getCurrentFrame(const QString &animationName);
    Q_INVOKABLE QString getCurrentFrameAsBase64(const QString &animationName);
    Q_INVOKABLE int getCurrentFrameIndex(const QString &animationName);
    Q_INVOKABLE int getFrameCount(const QString &animationName);
    Q_INVOKABLE bool isAnimationPlaying(const QString &animationName);
    
    // Méthode pour créer une animation de test
    Q_INVOKABLE void createTestAnimation(const QString &animationName, int numFrames = 20);
    
    // Méthode pour charger une animation depuis un dossier
    Q_INVOKABLE void loadAnimationFromFolder(const QString &animationName, const QString &folderPath);

signals:
    // Signal émis quand une frame change - solution de Harmen
    void frameChanged(const QString &animationName, int frameIndex);

private:
    struct AnimationData {
        QStringList framePaths;
        QList<QImage> frames;
        QStringList framesBase64; // Cache des frames en base64
        int currentFrame;
        bool isPlaying;
        QTimer* timer;
    };

    QMap<QString, AnimationData> m_animations;
    int m_defaultFrameRate;

    // Méthodes privées
    void nextFrame(const QString &animationName);
    void loadFrame(const QString &animationName, int frameIndex);
};

#endif // ANIMATION_MANAGER_H
