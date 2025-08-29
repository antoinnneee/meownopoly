#include "asset_manager.h"
#include <QDebug>
#include <QJsonParseError>
#include <QFileInfo>
#include <QQmlEngine>
#include <QDir>
#include <QImageReader>
#include <algorithm>
#include <type_traits>

AssetManager* AssetManager::m_pThis = nullptr;

// AssetModel Implementation
AssetModel::AssetModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int AssetModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    return m_assets.size();
}

QVariant AssetModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_assets.size())
        return QVariant();

    const Asset &asset = m_assets.at(index.row());

    switch (role) {
    case PathRole:
        return asset.path;
    case TypeRole:
        return asset.type;
    case CategoryRole:
        return asset.category;
    case RatioWidthRole:
        return asset.ratioWidth;
    case RatioHeightRole:
        return asset.ratioHeight;
    case WidthRole:
        return asset.width;
    case HeightRole:
        return asset.height;
    case IdRole:
        return asset.id;
    case FilenameRole:
        return asset.filename;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> AssetModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[PathRole] = "path";
    roles[TypeRole] = "type";
    roles[CategoryRole] = "category";
    roles[RatioWidthRole] = "ratioWidth";
    roles[RatioHeightRole] = "ratioHeight";
    roles[WidthRole] = "width";
    roles[HeightRole] = "height";
    roles[IdRole] = "id";
    roles[FilenameRole] = "filename";
    return roles;
}

void AssetModel::addAsset(const QString &path, const QString &type, const QString &category,
                         int ratioWidth, int ratioHeight, int width, int height, const QString &id, const QString &filename)
{
    beginInsertRows(QModelIndex(), m_assets.size(), m_assets.size());
    Asset asset;
    asset.path = path;
    asset.type = type;
    asset.category = category;
    asset.ratioWidth = ratioWidth;
    asset.ratioHeight = ratioHeight;
    asset.width = width;
    asset.height = height;
    asset.id = id;
    asset.filename = filename;
    m_assets.append(asset);
    endInsertRows();
}

void AssetModel::clear()
{
    beginResetModel();
    m_assets.clear();
    endResetModel();
}

AssetModel* AssetModel::createFilteredModel(const QString &type) const
{
    AssetModel *filteredModel = new AssetModel();
    
    for (const Asset &asset : m_assets) {
        if (asset.type == type) {
            filteredModel->addAsset(asset.path, asset.type, asset.category,
                                  asset.ratioWidth, asset.ratioHeight, asset.width, asset.height,
                                  asset.id, asset.filename);
        }
    }
    
    return filteredModel;
}

// AssetManager Implementation
AssetManager::AssetManager(QObject *parent)
    : QObject(parent)
    , m_decorationModel(new AssetModel(this))
    , m_tileModel(new AssetModel(this))
    , m_assetsBasePath(DEFAULT_ASSETS_LOCATION)
{
    m_pThis = this;
    loadAssets();
}

void AssetManager::registerQml()
{
    qmlRegisterSingletonType<AssetManager>("AssetManager", 1, 0, "AssetManager", &AssetManager::qmlInstance);
    qmlRegisterUncreatableType<AssetModel>("AssetManager", 1, 0, "AssetModel", "AssetModel cannot be created from QML");
}

AssetManager* AssetManager::instance()
{
    if (m_pThis == nullptr) // avoid creation of new instances
    {
        m_pThis = new AssetManager();
    }
    return m_pThis;
}

QObject* AssetManager::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);
    // C++ and QML instance they are the same instance
    return AssetManager::instance();
}

AssetModel* AssetManager::getTypeModel(const QString &category, const QString &type)
{
    QString key = category + "_" + type;
    
    if (m_filteredModels.contains(key)) {
        return m_filteredModels[key];
    }
    if (category == "decoration") {
        AssetModel *filteredModel = m_decorationModel->createFilteredModel(type);
        m_filteredModels[key] = filteredModel;
        return filteredModel;
    }
    if (category == "tile") {
        AssetModel *filteredModel = m_tileModel->createFilteredModel(type);
        m_filteredModels[key] = filteredModel;
        return filteredModel;
    }

    AssetModel *filteredModel = new AssetModel();
    filteredModel->setParent(this);
    m_filteredModels[key] = filteredModel;
    
    return filteredModel;
}

QString AssetManager::getAssetPath(const QString &category, const QString &type, const QString &id) const
{
    return buildAssetPath(category, type, id + ".png");
}

QString AssetManager::getDecorationPath(const QString &type, const QString &id) const
{
    return buildAssetPath("decoration", type, id + ".png");
}

QString AssetManager::getTilePath(const QString &type, const QString &id) const
{
    return buildAssetPath("tile", type, id + ".png");
}


void AssetManager::loadAssets()
{

    // Clear existing models
    m_decorationModel->clear();
    m_tileModel->clear();
    
    // Clear filtered models cache
    qDeleteAll(m_filteredModels);
    m_filteredModels.clear();
    
    QDir assetsDir(m_assetsBasePath);
    if (!assetsDir.exists()) {
        qWarning() << "Assets directory does not exist:" << m_assetsBasePath;
        return;
    }

    QStringList categories = assetsDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    setCategories(categories);
    qDebug() << "Categories:" << categories;
    for (const QString &category : categories) {
        QString categoryPath = assetsDir.absoluteFilePath(category); // basePath/category
        loadCategory(categoryPath, category);
    }

    
    
    emit decorationModelChanged();
    emit tileModelChanged();
    qDebug() << "Assets loaded successfully";
//    qDebug() << "Decorations:" << m_decorationModel->rowCount();
//    qDebug() << "Tiles:" << m_tileModel->rowCount();
}

void AssetManager::setAssetsBasePath(const QString &basePath)
{
    if (m_assetsBasePath != basePath) {
        m_assetsBasePath = basePath;
        emit assetsBasePathChanged();
        loadAssets(); // Reload assets with new path
    }
}

void AssetManager::setCategories(const QStringList &categories)
{
    if (m_categories != categories) {
        m_categories = categories;
        emit categoriesChanged();
    }
}

void AssetManager::loadCategory(const QString &categoryPath, const QString &categoryName)
{
    QDir categoryDir(categoryPath);
    
    QStringList typeDirectories = categoryDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    
    for (const QString &typeName : typeDirectories) {
        QString typePath = categoryDir.absoluteFilePath(typeName);
        loadTypeFromDirectory(typePath, typeName, categoryName);
    }
}

void AssetManager::loadTypeFromDirectory(const QString &typePath, const QString &typeName, const QString &categoryName)
{
    QDir typeDir(typePath);
    QString metadataPath = typeDir.absoluteFilePath("metadata.json");
    
    QFile metadataFile(metadataPath);
    if (!metadataFile.open(QIODevice::ReadOnly)) {
        qWarning() << "Cannot open metadata file:" << metadataPath;
        return;
    }
    
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(metadataFile.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        qWarning() << "JSON parse error in" << metadataPath << ":" << parseError.errorString();
        return;
    }
    
    QJsonObject rootObject = doc.object();
    QJsonArray assetsArray = rootObject["assets"].toArray();
    
    for (const QJsonValue &value : assetsArray) {
        QJsonObject assetObj = value.toObject();
        
        QString id = assetObj["id"].toString();
        QString filename = assetObj["filename"].toString();
        int ratioWidth = assetObj["ratioWidth"].toInt();
        int ratioHeight = assetObj["ratioHeight"].toInt();
        int width = assetObj["width"].toInt();
        int height = assetObj["height"].toInt();
        
        QString fullPath = buildAssetPath(categoryName, typeName, filename);
        
        // Add to appropriate model 
        // todo: select model from variable, list with type and model
        AssetModel *targetModel = nullptr;
        if (categoryName == "decoration") {
            targetModel = m_decorationModel;
        } else if (categoryName == "tile") {
            targetModel = m_tileModel;
        }
        else
        {
            QString key = categoryName + "_" + typeName;
            if (m_filteredModels.contains(key)) {
                targetModel = m_filteredModels[key];
            }
            else
            {
                targetModel = new AssetModel();
                m_filteredModels[key] = targetModel;
            }
        }
        
        if (targetModel) {
            targetModel->addAsset(fullPath, typeName, categoryName, ratioWidth, ratioHeight, width, height, id, filename);
        }
    }
}


QString AssetManager::buildAssetPath(const QString &category, const QString &type, const QString &filename) const
{
    QDir assetsDir(m_assetsBasePath);
    
    if (type.isEmpty()) {
        // For categories without types (like player_icons)
        return "file:///" + assetsDir.absoluteFilePath(category + "/" + filename);
    } else {
        // For categories with types (like decoration/grass, decoration/tree)
        return "file:///" + assetsDir.absoluteFilePath(category + "/" + type + "/" + filename);
    }
}

bool AssetManager::generateMetadataForDirectory(const QString &directoryPath)
{
    QDir dir(directoryPath);
    if (!dir.exists()) {
        qWarning() << "Directory does not exist:" << directoryPath;
        return false;
    }
    
    // Get all PNG files in the directory
    QStringList filters;
    filters << "*.png" << "*.jpg" << "*.jpeg";  // maybe not work with other than png
    QStringList imageFiles = dir.entryList(filters, QDir::Files);
    
    if (imageFiles.isEmpty()) {
        qWarning() << "No image files found in:" << directoryPath;
        return false;
    }
    
    // Sort files naturally (1.png, 2.png, 10.png, etc.)
    std::sort(imageFiles.begin(), imageFiles.end(), [](const QString &a, const QString &b) {
        QFileInfo fileInfoA(a);
        QFileInfo fileInfoB(b);
        
        // Extract numbers from filenames for natural sorting
        QString baseA = fileInfoA.baseName();
        QString baseB = fileInfoB.baseName();
        
        bool okA, okB;
        int numA = baseA.toInt(&okA);
        int numB = baseB.toInt(&okB);
        
        if (okA && okB) {
            return numA < numB;
        }
        
        return a < b;
    });
    
    QJsonArray assetsArray;
    
    for (int i = 0; i < imageFiles.size(); ++i) {
        const QString &filename = imageFiles[i];
        QString fullPath = dir.absoluteFilePath(filename);
        
        // Read image dimensions
        QImageReader reader(fullPath);
        QSize imageSize = reader.size();
        
        if (!imageSize.isValid()) {
            qWarning() << "Cannot read image dimensions for:" << fullPath;
            continue;
        }
        
        // Generate ID from filename (remove extension)
        QFileInfo fileInfo(filename);
        QString id = fileInfo.baseName();
        
        // Calculate ratio as integers
        int w = imageSize.width();
        int h = imageSize.height();
        // Find GCD to simplify the ratio
        int a = w;
        int b = h;
        while (b != 0) {
            int temp = b;
            b = a % b;
            a = temp;
        }
        int gcd = a;
        int ratioWidth = w / gcd;
        int ratioHeight = h / gcd;
        
        // Create asset object
        QJsonObject assetObj;
        assetObj["id"] = id;
        assetObj["filename"] = filename;
        assetObj["ratioWidth"] = ratioWidth;
        assetObj["ratioHeight"] = ratioHeight;
        assetObj["width"] = imageSize.width();
        assetObj["height"] = imageSize.height();
        
        assetsArray.append(assetObj);
    }
    
    // Create metadata object
    QJsonObject metadataObj;
    metadataObj["assets"] = assetsArray;
    
    // Write to metadata.json
    QString metadataPath = dir.absoluteFilePath("metadata.json");
    QFile metadataFile(metadataPath);
    
    if (!metadataFile.open(QIODevice::WriteOnly)) {
        qWarning() << "Cannot create metadata file:" << metadataPath;
        return false;
    }
    
    QJsonDocument doc(metadataObj);
    metadataFile.write(doc.toJson());
    metadataFile.close();
    
    qDebug() << "Generated metadata for" << imageFiles.size() << "assets in:" << directoryPath;
    qDebug() << "Metadata saved to:" << metadataPath;
    
    return true;
}

bool AssetManager::generateAllMetadata()
{
    QDir assetsDir(m_assetsBasePath);
    if (!assetsDir.exists()) {
        qWarning() << "Assets base directory does not exist:" << m_assetsBasePath;
        return false;
    }
    
    bool success = true;
    int generatedCount = 0;
    
    for (const QString &category : m_categories) {
        QString categoryPath = assetsDir.absoluteFilePath(category);
        QDir categoryDir(categoryPath);
        if (categoryDir.exists()) {
            QStringList typeDirectories = categoryDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
            for (const QString &typeName : typeDirectories) {
                QString typePath = categoryDir.absoluteFilePath(typeName);
                if (generateMetadataForDirectory(typePath)) {
                    generatedCount++;
                } else {
                    success = false;
                }
            }
        }
    }
    
    qDebug() << "Generated metadata for" << generatedCount << "directories";
    
    // Reload assets after generation
    if (success && generatedCount > 0) {
        loadAssets();
    }
    
    return success;
}

QStringList AssetManager::scanAvailableAssets()
{
    QStringList result;
    QDir assetsDir(m_assetsBasePath);
    
    if (!assetsDir.exists()) {
        return result;
    }
    
    loadAssets(); // load assets to get categories

    for (const QString &category : m_categories) {
        QString categoryPath = assetsDir.absoluteFilePath(category);
        QDir categoryDir(categoryPath);
        if (categoryDir.exists()) {
            QStringList typeDirectories = categoryDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        
            for (const QString &typeName : typeDirectories) {
                QString typePath = categoryDir.absoluteFilePath(typeName);
                QDir typeDir(typePath);
                
                QStringList filters;
                filters << "*.png" << "*.jpg" << "*.jpeg";
                QStringList imageFiles = typeDir.entryList(filters, QDir::Files);
                if (!imageFiles.isEmpty()) {
                    result << QString("%1/%2 (%3 images)").arg(category).arg(typeName).arg(imageFiles.size());
                }
            }
        }
    }

    return result;
}

QStringList AssetManager::getAvailableTypes(const QString &category) const
{
    QStringList types;
    QDir assetsDir(m_assetsBasePath);
    
    if (!assetsDir.exists()) {
        return types;
    }
    
    QString categoryPath = assetsDir.absoluteFilePath(category);
    QDir categoryDir(categoryPath);
    
    if (!categoryDir.exists()) {
        return types;
    }
    
    // For categories with subdirectories (like decoration), return the subdirectory names
    QStringList typeDirectories = categoryDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    
    for (const QString &typeName : typeDirectories) {
        QString typePath = categoryDir.absoluteFilePath(typeName);
        QDir typeDir(typePath);
        
        QStringList filters;
        filters << "*.png" << "*.jpg" << "*.jpeg";
        QStringList imageFiles = typeDir.entryList(filters, QDir::Files);
        
        if (!imageFiles.isEmpty()) {
            types << typeName;
        }
    }
    
    return types;
}

QStringList AssetManager::getAvailableCategories() const
{
    QDir assetsDir(m_assetsBasePath);
    
    if (!assetsDir.exists()) {
        return m_categories;
    }
    
    
    return m_categories;
}
