#ifndef TEMPLATEFILEMANAGER_H
#define TEMPLATEFILEMANAGER_H

#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <QStringList>
#include <QQmlEngine>
#define DEFAULT_TEMPLATE_PATH ("./template/default/")
#define USER_TEMPLATE_PATH ("./template/user/")

class TemplateFileManager : public QObject
{
    Q_OBJECT

public:
    enum TemplateType {
        DEFAULT,
        USER
    };
    Q_ENUM(TemplateType)

    static void registerQml();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);
    static TemplateFileManager *instance();

    Q_INVOKABLE bool templateExists(const QString &templateName, TemplateType type = USER);
    Q_INVOKABLE QStringList getAvailableTemplates(TemplateType type = USER);
    Q_INVOKABLE QStringList getAllTemplates();
    Q_INVOKABLE QString findTemplateByName(const QString &displayName);
    Q_INVOKABLE QString createTemplateFile(const QString &templateName);
    Q_INVOKABLE bool deleteTemplate(const QString &templateName);
    Q_INVOKABLE bool renameTemplate(const QString &oldName, const QString &newName);
    Q_INVOKABLE QJsonObject getTemplateInfo(const QString &templateName);
    Q_INVOKABLE TemplateType getTemplateType(const QString &templateName);
    Q_INVOKABLE bool isDefaultTemplate(const QString &templateName);

    static QJsonObject readTemplateFile(const QString &templateName, TemplateType type = USER);
    static bool saveTemplate(const QJsonObject &templateData, const QString &templateName, TemplateType type = USER);
    static bool removeTemplateFile(const QString &templateName, TemplateType type = USER);
    static QString normalizeTemplateName(const QString &templateName);
    static QString getTemplateFilePath(const QString &templateName, TemplateType type);
    static QJsonArray convertElementsToTemplateFormat(const QJsonArray &elements, int originX, int originY);
    static QJsonArray convertTemplateElementsToMapFormat(const QJsonArray &templateElements, int targetX, int targetY);

private:
    explicit TemplateFileManager(QObject *parent = nullptr);
    static TemplateFileManager *m_instance;
    void ensureDirectoriesExist();
};

#endif // TEMPLATEFILEMANAGER_H