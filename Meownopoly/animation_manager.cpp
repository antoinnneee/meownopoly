#include "animation_manager.h"
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QPainter>
#include <QFont>
#include <QColor>
#include <QtMath>
#include <QBuffer>

AnimationManager::AnimationManager(QObject *parent)
    : QObject(parent)
    , m_defaultFrameRate(30)
{
}

AnimationManager::~AnimationManager()
{
    // Arrêter tous les timers
    for (auto it = m_animations.begin(); it != m_animations.end(); ++it) {
        if (it->timer) {
            it->timer->stop();
            it->timer->deleteLater();
        }
    }
}

void AnimationManager::loadAnimation(const QString &animationName, const QStringList &framePaths)
{
    AnimationData animation;
    animation.framePaths = framePaths;
    animation.currentFrame = 0;
    animation.isPlaying = false;
    animation.timer = nullptr;

    qDebug() << "AnimationManager: Début du chargement de l'animation:" << animationName;

    // Charger toutes les frames et les convertir en base64
    for (int i = 0; i < framePaths.size(); ++i) {
        const QString &path = framePaths[i];
        QImage frame(path);
        if (!frame.isNull()) {
            animation.frames.append(frame);
            
            // Précharger la frame en base64 pour éviter la conversion à chaque frame
            QByteArray ba;
            QBuffer buffer(&ba);
            buffer.open(QIODevice::WriteOnly);
            frame.save(&buffer, "PNG");
            animation.framesBase64.append(QString(ba.toBase64()));
            
            qDebug() << "AnimationManager: Frame" << (i+1) << "chargée et convertie en base64:" << path;
        } else {
            qWarning() << "AnimationManager: Impossible de charger la frame:" << path;
        }
    }

    if (!animation.frames.isEmpty()) {
        m_animations[animationName] = animation;
        qDebug() << "AnimationManager: Animation chargée:" << animationName 
                 << "avec" << animation.frames.size() << "frames (toutes préchargées en base64)";
    } else {
        qWarning() << "AnimationManager: Aucune frame valide trouvée pour:" << animationName;
    }
}

void AnimationManager::startAnimation(const QString &animationName, int frameRate)
{
    if (!m_animations.contains(animationName)) {
        qWarning() << "AnimationManager: Animation non trouvée:" << animationName;
        return;
    }

    AnimationData &animation = m_animations[animationName];
    
    if (animation.frames.isEmpty()) {
        qWarning() << "AnimationManager: Aucune frame disponible pour:" << animationName;
        return;
    }

    // Arrêter le timer existant s'il y en a un
    if (animation.timer) {
        animation.timer->stop();
        animation.timer->deleteLater();
    }

    // Créer un nouveau timer
    animation.timer = new QTimer();
    animation.timer->setInterval(1000 / frameRate); // Convertir FPS en intervalle en ms
    
    // Connecter le signal au slot pour passer à la frame suivante
    QObject::connect(animation.timer, &QTimer::timeout, [this, animationName]() {
        nextFrame(animationName);
    });

    animation.isPlaying = true;
    animation.timer->start();
    
    qDebug() << "AnimationManager: Animation démarrée:" << animationName 
             << "à" << frameRate << "FPS";
}

void AnimationManager::stopAnimation(const QString &animationName)
{
    if (!m_animations.contains(animationName)) {
        return;
    }

    AnimationData &animation = m_animations[animationName];
    
    if (animation.timer) {
        animation.timer->stop();
        animation.timer->deleteLater();
        animation.timer = nullptr;
    }
    
    animation.isPlaying = false;
    qDebug() << "AnimationManager: Animation arrêtée:" << animationName;
}

void AnimationManager::setCurrentFrame(const QString &animationName, int frameIndex)
{
    if (!m_animations.contains(animationName)) {
        return;
    }

    AnimationData &animation = m_animations[animationName];
    
    if (frameIndex >= 0 && frameIndex < animation.frames.size()) {
        animation.currentFrame = frameIndex;
        // Émettre le signal pour notifier QML du changement
        emit frameChanged(animationName, animation.currentFrame);
    }
}

QImage AnimationManager::getCurrentFrame(const QString &animationName)
{
    if (!m_animations.contains(animationName)) {
        return QImage();
    }

    const AnimationData &animation = m_animations[animationName];
    
    if (animation.currentFrame < animation.frames.size()) {
        return animation.frames[animation.currentFrame];
    }

    return QImage();
}

QString AnimationManager::getCurrentFrameAsBase64(const QString &animationName)
{
    if (!m_animations.contains(animationName)) {
        return QString();
    }

    const AnimationData &animation = m_animations[animationName];
    
    if (animation.currentFrame < animation.framesBase64.size()) {
        // Retourner directement la frame préchargée en base64
        return animation.framesBase64[animation.currentFrame];
    }

    return QString();
}

int AnimationManager::getCurrentFrameIndex(const QString &animationName)
{
    if (!m_animations.contains(animationName)) {
        return -1;
    }

    return m_animations[animationName].currentFrame;
}

int AnimationManager::getFrameCount(const QString &animationName)
{
    if (!m_animations.contains(animationName)) {
        return 0;
    }

    return m_animations[animationName].frames.size();
}

bool AnimationManager::isAnimationPlaying(const QString &animationName)
{
    if (!m_animations.contains(animationName)) {
        return false;
    }

    return m_animations[animationName].isPlaying;
}

void AnimationManager::nextFrame(const QString &animationName)
{
    if (!m_animations.contains(animationName)) {
        return;
    }

    AnimationData &animation = m_animations[animationName];
    
    if (animation.frames.isEmpty()) {
        return;
    }

    // Passer à la frame suivante (boucle)
    animation.currentFrame = (animation.currentFrame + 1) % animation.frames.size();
    
    // Émettre le signal pour notifier QML - solution de Harmen
    emit frameChanged(animationName, animation.currentFrame);
    
    qDebug() << "AnimationManager: Frame suivante:" << animationName << "à" << animation.currentFrame;
}

void AnimationManager::loadFrame(const QString &animationName, int frameIndex)
{
    if (!m_animations.contains(animationName)) {
        return;
    }

    AnimationData &animation = m_animations[animationName];
    
    if (frameIndex < 0 || frameIndex >= animation.framePaths.size()) {
        return;
    }

    // Charger la frame si elle n'est pas déjà en mémoire
    if (frameIndex >= animation.frames.size()) {
        QImage frame(animation.framePaths[frameIndex]);
        if (!frame.isNull()) {
            animation.frames.append(frame);
        }
    }
}

void AnimationManager::createTestAnimation(const QString &animationName, int numFrames)
{
    AnimationData animation;
    animation.currentFrame = 0;
    animation.isPlaying = false;
    animation.timer = nullptr;

    qDebug() << "AnimationManager: Création de l'animation de test:" << animationName;

    // Créer les frames de test et les précharger en base64
    for (int frame = 0; frame < numFrames; ++frame) {
        QImage frameImage(100, 100, QImage::Format_ARGB32);
        frameImage.fill(Qt::transparent);
        
        QPainter painter(&frameImage);
        painter.setRenderHint(QPainter::Antialiasing);
        
        // Calculer la position du cercle (mouvement circulaire)
        qreal angle = (frame / qreal(numFrames)) * 2 * M_PI;
        qreal centerX = 50.0;
        qreal centerY = 50.0;
        qreal radius = 30.0;
        
        qreal x = centerX + radius * qCos(angle);
        qreal y = centerY + radius * qSin(angle);
        
        // Dessiner le cercle
        painter.setBrush(QColor(255, 100, 100, 255));
        painter.setPen(QPen(QColor(200, 50, 50, 255), 2));
        painter.drawEllipse(QPointF(x, y), 10, 10);
        
        // Ajouter le numéro de frame
        painter.setPen(QPen(Qt::white, 1));
        QFont font = painter.font();
        font.setPixelSize(12);
        painter.setFont(font);
        painter.drawText(5, 15, QString("F%1").arg(frame));
        
        painter.end();
        
        animation.frames.append(frameImage);
        
        // Précharger la frame en base64
        QByteArray ba;
        QBuffer buffer(&ba);
        buffer.open(QIODevice::WriteOnly);
        frameImage.save(&buffer, "PNG");
        animation.framesBase64.append(QString(ba.toBase64()));
    }

    m_animations[animationName] = animation;
    qDebug() << "AnimationManager: Animation de test créée:" << animationName 
             << "avec" << animation.frames.size() << "frames (toutes préchargées en base64)";
}

void AnimationManager::loadAnimationFromFolder(const QString &animationName, const QString &folderPath)
{
    QDir dir(folderPath);
    if (!dir.exists()) {
        qWarning() << "AnimationManager: Le dossier n'existe pas:" << folderPath;
        return;
    }

    // Obtenir tous les fichiers PNG du dossier
    QStringList filters;
    filters << "*.png" << "*.jpg" << "*.jpeg";
    dir.setNameFilters(filters);
    dir.setSorting(QDir::Name); // Trier par nom pour avoir l'ordre correct
    
    QStringList framePaths = dir.entryList(QDir::Files);
    
    if (framePaths.isEmpty()) {
        qWarning() << "AnimationManager: Aucune image trouvée dans le dossier:" << folderPath;
        return;
    }

    // Construire les chemins complets
    QStringList fullPaths;
    for (const QString &fileName : framePaths) {
        fullPaths.append(dir.absoluteFilePath(fileName));
    }

    // Charger l'animation avec les chemins complets
    loadAnimation(animationName, fullPaths);
    
    qDebug() << "AnimationManager: Animation chargée depuis le dossier:" << folderPath 
             << "avec" << fullPaths.size() << "frames";
}
