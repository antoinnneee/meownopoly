#ifndef TEMPLATEFILEMANAGER_H
#define TEMPLATEFILEMANAGER_H

#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <QStringList>
#include <QQmlEngine>
#include <QVariantMap>

#define TEMPLATE_FILE_PATH ("./templates/")

class TemplateFileManager : public QObject
{
    Q_OBJECT

public:
    // QML registration (même pattern que Game)
    static void registerQml();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);
    static TemplateFileManager *instance();

    // Méthodes QML (instance, Q_INVOKABLE)
    Q_INVOKABLE bool templateExists(const QString &templateName);
    Q_INVOKABLE QStringList getAvailableTemplates();
    Q_INVOKABLE QString getTemplatePath(const QString &templateName);

    // Méthodes C++ internes (static) - utilisées par Game
    static QJsonObject readTemplateFile(const QString &templateName);
    static bool writeTemplateFile(const QJsonObject &templateData, const QString &templateName);
    static bool removeTemplateFile(const QString &templateName);
    
    // Utility methods (static) - conversion de positions
    static QString normalizeTemplateName(const QString &templateName);
    static QVariantMap calculateBoundingBox(const QJsonArray &elementsArray);
    static QJsonArray convertToRelativePositions(const QJsonArray &elementsArray, int originX, int originY);
    static QJsonArray convertToAbsolutePositions(const QJsonArray &elementsArray, int targetX, int targetY);
    static QJsonArray regenerateUniqueIds(const QJsonArray &elementsArray);

private:
    explicit TemplateFileManager(QObject *parent = nullptr);
    static TemplateFileManager *m_instance;
    
    // Helpers internes
    static QString getTemplateFilePath(const QString &templateName);
    static void ensureTemplateDirectoryExists();
};

#endif // TEMPLATEFILEMANAGER_H
