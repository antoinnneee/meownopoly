 #ifndef TEMPLATEMANAGER_H
#define TEMPLATEMANAGER_H

#include <QObject>
#include <QQmlEngine>
#include <QJsonObject>
#include <QJsonArray>
#include <QList>
#include <QVariantList>
#include "templateinfo.h"
#include "templatefilemanager.h"
#include "game/item_snapable/ItemSnapable.h"

class TemplateManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentTemplateName READ currentTemplateName WRITE setCurrentTemplateName NOTIFY currentTemplateNameChanged)
    Q_PROPERTY(QJsonObject currentTemplateData READ currentTemplateData NOTIFY currentTemplateDataChanged)
    Q_PROPERTY(bool hasCurrentTemplate READ hasCurrentTemplate NOTIFY currentTemplateDataChanged)

public:
    static void registerQml();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);
    static TemplateManager *instance();

    QString currentTemplateName() const;
    void setCurrentTemplateName(const QString &name);
    QJsonObject currentTemplateData() const;
    bool hasCurrentTemplate() const;

    Q_INVOKABLE bool createTemplateFromElements(const QString &templateName, QVariantList elements);
    Q_INVOKABLE bool createTemplateFromJson(const QString &templateName, const QJsonArray &elementsJson);
    Q_INVOKABLE bool selectTemplate(const QString &templateName);
    Q_INVOKABLE void clearSelection();
    Q_INVOKABLE QList<ItemSnapable*> generateTemplateElements(int targetGridX, int targetGridY);
    Q_INVOKABLE QJsonArray generateTemplateElementsJson(int targetGridX, int targetGridY);
    Q_INVOKABLE QVariantMap getCurrentTemplateBounds() const;
    Q_INVOKABLE bool deleteTemplate(const QString &templateName);
    Q_INVOKABLE void refreshTemplates();

signals:
    void currentTemplateNameChanged();
    void currentTemplateDataChanged();
    void templateCreated(const QString &templateName);
    void templateDeleted(const QString &templateName);
    void templateSelected(const QString &templateName);
    void templatePlaced(int gridX, int gridY, int elementCount);

private:
    explicit TemplateManager(QObject *parent = nullptr);
    static TemplateManager *m_instance;
    QString m_currentTemplateName;
    QJsonObject m_currentTemplateData;

    struct BoundingBox {
        int minX = INT_MAX;
        int minY = INT_MAX;
        int maxX = INT_MIN;
        int maxY = INT_MIN;
        int width() const { return maxX - minX; }
        int height() const { return maxY - minY; }
    };
    BoundingBox calculateBoundingBox(const QJsonArray &elements) const;
};

#endif // TEMPLATEMANAGER_H
