#ifndef TEMPLATEMODEL_H
#define TEMPLATEMODEL_H

#include <QAbstractListModel>
#include <QJsonObject>
#include <QList>
#include "templateinfo.h"
#include "templatefilemanager.h"

/**
 * @brief Modèle de liste pour afficher les templates dans QML
 * 
 * Ce modèle expose une liste de templates (par défaut et utilisateur)
 * pour utilisation dans des ListView, GridView, etc. en QML.
 */
class TemplateModel : public QAbstractListModel
{
    Q_OBJECT
    
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum TemplateRoles {
        NameRole = Qt::UserRole + 1,
        DescriptionRole,
        CreationDateRole,
        AuthorRole,
        VersionRole,
        BoundingBoxWidthRole,
        BoundingBoxHeightRole,
        OriginOffsetXRole,
        OriginOffsetYRole,
        ElementCountRole,
        ThumbnailPathRole,
        IsDefaultRole,
        FilePathRole
    };
    Q_ENUM(TemplateRoles)

    explicit TemplateModel(QObject *parent = nullptr);
    ~TemplateModel();

    static void registerQml();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);
    static TemplateModel *instance();

    // QAbstractListModel interface
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Propriétés
    int count() const;

    // Méthodes Q_INVOKABLE pour QML
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void loadTemplates();
    Q_INVOKABLE QJsonObject getTemplateData(int index) const;
    Q_INVOKABLE QJsonObject getTemplateDataByName(const QString &name) const;
    Q_INVOKABLE int indexOf(const QString &templateName) const;
    Q_INVOKABLE QString getTemplateName(int index) const;
    Q_INVOKABLE bool isDefault(int index) const;

signals:
    void countChanged();
    void templatesLoaded();

private:
    struct TemplateData {
        QString name;
        QString description;
        QString creationDate;
        QString author;
        int version;
        int boundingBoxWidth;
        int boundingBoxHeight;
        int originOffsetX;
        int originOffsetY;
        int elementCount;
        QString thumbnailPath;
        bool isDefault;
        QString filePath;
        QJsonObject fullData;  // Données complètes du template
    };

    QList<TemplateData> m_templates;
    static TemplateModel *m_instance;

    void loadTemplateInfo(const QString &templateName, TemplateFileManager::TemplateType type);
};

#endif // TEMPLATEMODEL_H

