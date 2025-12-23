#include "templatemodel.h"
#include <QQmlEngine>
#include <QDebug>

// Static member initialization
TemplateModel *TemplateModel::m_instance = nullptr;

TemplateModel::TemplateModel(QObject *parent)
    : QAbstractListModel(parent)
{
    loadTemplates();
}

TemplateModel::~TemplateModel()
{
}

void TemplateModel::registerQml()
{
    qmlRegisterSingletonType<TemplateModel>("TemplateModel", 1, 0, "TemplateModel", &TemplateModel::qmlInstance);
}

QObject *TemplateModel::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)
    return TemplateModel::instance();
}

TemplateModel *TemplateModel::instance()
{
    if (!m_instance) {
        m_instance = new TemplateModel();
    }
    return m_instance;
}

int TemplateModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_templates.count();
}

QVariant TemplateModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_templates.count())
        return QVariant();

    const TemplateData &templateData = m_templates.at(index.row());

    switch (role) {
    case NameRole:
        return templateData.name;
    case DescriptionRole:
        return templateData.description;
    case CreationDateRole:
        return templateData.creationDate;
    case AuthorRole:
        return templateData.author;
    case VersionRole:
        return templateData.version;
    case BoundingBoxWidthRole:
        return templateData.boundingBoxWidth;
    case BoundingBoxHeightRole:
        return templateData.boundingBoxHeight;
    case OriginOffsetXRole:
        return templateData.originOffsetX;
    case OriginOffsetYRole:
        return templateData.originOffsetY;
    case ElementCountRole:
        return templateData.elementCount;
    case ThumbnailPathRole:
        return templateData.thumbnailPath;
    case IsDefaultRole:
        return templateData.isDefault;
    case FilePathRole:
        return templateData.filePath;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> TemplateModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[NameRole] = "name";
    roles[DescriptionRole] = "description";
    roles[CreationDateRole] = "creationDate";
    roles[AuthorRole] = "author";
    roles[VersionRole] = "version";
    roles[BoundingBoxWidthRole] = "boundingBoxWidth";
    roles[BoundingBoxHeightRole] = "boundingBoxHeight";
    roles[OriginOffsetXRole] = "originOffsetX";
    roles[OriginOffsetYRole] = "originOffsetY";
    roles[ElementCountRole] = "elementCount";
    roles[ThumbnailPathRole] = "thumbnailPath";
    roles[IsDefaultRole] = "isDefault";
    roles[FilePathRole] = "filePath";
    return roles;
}

int TemplateModel::count() const
{
    return m_templates.count();
}

void TemplateModel::refresh()
{
    loadTemplates();
}

void TemplateModel::loadTemplates()
{
    beginResetModel();
    m_templates.clear();

    TemplateFileManager *manager = TemplateFileManager::instance();

    // Charger d'abord les templates par défaut
    QStringList defaultTemplates = manager->getAvailableTemplates(TemplateFileManager::DEFAULT);
    for (const QString &templateName : defaultTemplates) {
        loadTemplateInfo(templateName, TemplateFileManager::DEFAULT);
    }

    // Puis les templates utilisateur
    QStringList userTemplates = manager->getAvailableTemplates(TemplateFileManager::USER);
    for (const QString &templateName : userTemplates) {
        loadTemplateInfo(templateName, TemplateFileManager::USER);
    }

    endResetModel();
    emit countChanged();
    emit templatesLoaded();

    qDebug() << "TemplateModel: Loaded" << m_templates.count() << "templates";
}

void TemplateModel::loadTemplateInfo(const QString &templateName, TemplateFileManager::TemplateType type)
{
    QJsonObject fullData = TemplateFileManager::readTemplateFile(templateName, type);
    if (fullData.isEmpty()) {
        qDebug() << "Failed to load template:" << templateName;
        return;
    }

    QJsonObject info = fullData["templateInfo"].toObject();

    TemplateData data;
    data.name = info["name"].toString(templateName);
    data.description = info["description"].toString();
    data.creationDate = info["creationDate"].toString();
    data.author = info["author"].toString();
    data.version = info["version"].toInt(1);
    data.boundingBoxWidth = info["boundingBoxWidth"].toInt(0);
    data.boundingBoxHeight = info["boundingBoxHeight"].toInt(0);
    data.originOffsetX = info["originOffsetX"].toInt(0);
    data.originOffsetY = info["originOffsetY"].toInt(0);
    data.elementCount = info["elementCount"].toInt(0);
    data.thumbnailPath = info["thumbnailPath"].toString();
    data.isDefault = (type == TemplateFileManager::DEFAULT);
    data.filePath = TemplateFileManager::getTemplateFilePath(templateName, type);
    data.fullData = fullData;

    m_templates.append(data);
}

QJsonObject TemplateModel::getTemplateData(int index) const
{
    if (index < 0 || index >= m_templates.count())
        return QJsonObject();
    
    return m_templates.at(index).fullData;
}

QJsonObject TemplateModel::getTemplateDataByName(const QString &name) const
{
    int idx = indexOf(name);
    if (idx >= 0) {
        return getTemplateData(idx);
    }
    return QJsonObject();
}

int TemplateModel::indexOf(const QString &templateName) const
{
    QString normalized = TemplateFileManager::normalizeTemplateName(templateName);
    for (int i = 0; i < m_templates.count(); ++i) {
        if (TemplateFileManager::normalizeTemplateName(m_templates.at(i).name) == normalized) {
            return i;
        }
    }
    return -1;
}

QString TemplateModel::getTemplateName(int index) const
{
    if (index < 0 || index >= m_templates.count())
        return QString();
    
    return m_templates.at(index).name;
}

bool TemplateModel::isDefault(int index) const
{
    if (index < 0 || index >= m_templates.count())
        return false;
    
    return m_templates.at(index).isDefault;
}

