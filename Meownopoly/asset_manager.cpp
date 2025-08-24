#include "asset_manager.h"
#include <QDebug>
#include <QJsonParseError>
#include <QFileInfo>
#include <QQmlEngine>
#include <QDir>
#include <QImageReader>
#include <algorithm>

AssetManager* AssetManager::s_instance = nullptr;

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
    case RatioRole:
        return asset.ratio;
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
    roles[RatioRole] = "ratio";
    roles[WidthRole] = "width";
    roles[HeightRole] = "height";
    roles[IdRole] = "id";
    roles[FilenameRole] = "filename";
    return roles;
}

void AssetModel::addAsset(const QString &path, const QString &type, const QString &category,
                         double ratio, int width, int height, const QString &id, const QString &filename)
{
    beginInsertRows(QModelIndex(), m_assets.size(), m_assets.size());
    Asset asset;
    asset.path = path;
    asset.type = type;
    asset.category = category;
    asset.ratio = ratio;
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
                                  asset.ratio, asset.width, asset.height,
                                  asset.id, asset.filename);
        }
    }
    
    return filteredModel;
}

// AssetManager Implementation
AssetManager::AssetManager(QObject *parent)
    : QObject(parent)
    , m_decorationModel(new AssetModel(this))
    , m_playerIconModel(new AssetModel(this))
    , m_assetsBasePath("asset_extracted/")
{
    s_instance = this;
}

void AssetManager::registerQml()
{
    qmlRegisterType<AssetManager>("AssetManager", 1, 0, "AssetManager");
    qmlRegisterUncreatableType<AssetModel>("AssetManager", 1, 0, "AssetModel", "AssetModel cannot be created from QML");
}

AssetManager* AssetManager::instance()
{
    if (!s_instance) {
        s_instance = new AssetManager();
    }
    return s_instance;
}

AssetModel* AssetManager::getTypeModel(const QString &category, const QString &type)
{
    QString key = category + "_" + type;
    
    if (m_filteredModels.contains(key)) {
        return m_filteredModels[key];
    }
    
    AssetModel *sourceModel = nullptr;
    if (category == "decoration") {
        sourceModel = m_decorationModel;
    } else if (category == "player_icons") {
        sourceModel = m_playerIconModel;
    }
    
    if (!sourceModel) {
        qWarning() << "Unknown category:" << category;
        return nullptr;
    }
    
    AssetModel *filteredModel = sourceModel->createFilteredModel(type);
    filteredModel->setParent(this);
    m_filteredModels[key] = filteredModel;
    
    return filteredModel;
}

QString AssetManager::getDecorationPath(const QString &type, const QString &id) const
{
    return buildAssetPath("decoration", type, id + ".png");
}

QString AssetManager::getPlayerIconPath(const QString &id) const
{
    return buildAssetPath("player_icons", "", id + ".png");
}

void AssetManager::loadAssets()
{
    qDebug() << "Loading assets from:" << m_assetsBasePath;
    
    // Clear existing models
    m_decorationModel->clear();
    m_playerIconModel->clear();
    
    // Clear filtered models cache
    qDeleteAll(m_filteredModels);
    m_filteredModels.clear();
    
    QDir assetsDir(m_assetsBasePath);
    if (!assetsDir.exists()) {
        qWarning() << "Assets directory does not exist:" << m_assetsBasePath;
        return;
    }
    
    // Load decorations
    QString decorationPath = assetsDir.absoluteFilePath("decoration");
    if (QDir(decorationPath).exists()) {
        loadCategory(decorationPath, "decoration");
    }
    
    // Load player icons
    QString playerIconsPath = assetsDir.absoluteFilePath("player_icons");
    if (QDir(playerIconsPath).exists()) {
        loadCategory(playerIconsPath, "player_icons");
    }
    
    emit decorationModelChanged();
    emit playerIconModelChanged();
    
    qDebug() << "Assets loaded successfully";
    qDebug() << "Decorations:" << m_decorationModel->rowCount();
    qDebug() << "Player icons:" << m_playerIconModel->rowCount();
}

void AssetManager::setAssetsBasePath(const QString &basePath)
{
    if (m_assetsBasePath != basePath) {
        m_assetsBasePath = basePath;
        emit assetsBasePathChanged();
        loadAssets(); // Reload assets with new path
    }
}

void AssetManager::loadCategory(const QString &categoryPath, const QString &categoryName)
{
    QDir categoryDir(categoryPath);
    
    if (categoryName == "player_icons") {
        // For player_icons, load directly from the category directory
        loadTypeFromDirectory(categoryPath, "", categoryName);
    } else {
        // For other categories like decoration, load from subdirectories (types)
        QStringList typeDirectories = categoryDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        
        for (const QString &typeName : typeDirectories) {
            QString typePath = categoryDir.absoluteFilePath(typeName);
            loadTypeFromDirectory(typePath, typeName, categoryName);
        }
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
        double ratio = assetObj["ratio"].toDouble();
        int width = assetObj["width"].toInt();
        int height = assetObj["height"].toInt();
        
        QString fullPath = buildAssetPath(categoryName, typeName, filename);
        
        // Add to appropriate model
        AssetModel *targetModel = nullptr;
        if (categoryName == "decoration") {
            targetModel = m_decorationModel;
        } else if (categoryName == "player_icons") {
            targetModel = m_playerIconModel;
        }
        
        if (targetModel) {
            targetModel->addAsset(fullPath, typeName, categoryName, ratio, width, height, id, filename);
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
    filters << "*.png" << "*.jpg" << "*.jpeg";
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
        
        // Calculate ratio
        double ratio = static_cast<double>(imageSize.width()) / imageSize.height();
        
        // Create asset object
        QJsonObject assetObj;
        assetObj["id"] = id;
        assetObj["filename"] = filename;
        assetObj["ratio"] = ratio;
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
    
    // Generate for decoration subdirectories
    QString decorationPath = assetsDir.absoluteFilePath("decoration");
    QDir decorationDir(decorationPath);
    if (decorationDir.exists()) {
        QStringList typeDirectories = decorationDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        
        for (const QString &typeName : typeDirectories) {
            QString typePath = decorationDir.absoluteFilePath(typeName);
            if (generateMetadataForDirectory(typePath)) {
                generatedCount++;
            } else {
                success = false;
            }
        }
    }
    
    // Generate for player_icons directory
    QString playerIconsPath = assetsDir.absoluteFilePath("player_icons");
    if (QDir(playerIconsPath).exists()) {
        if (generateMetadataForDirectory(playerIconsPath)) {
            generatedCount++;
        } else {
            success = false;
        }
    }
    
    qDebug() << "Generated metadata for" << generatedCount << "directories";
    
    // Reload assets after generation
    if (success && generatedCount > 0) {
        loadAssets();
    }
    
    return success;
}

QStringList AssetManager::scanAvailableAssets() const
{
    QStringList result;
    QDir assetsDir(m_assetsBasePath);
    
    if (!assetsDir.exists()) {
        return result;
    }
    
    // Scan decoration types
    QString decorationPath = assetsDir.absoluteFilePath("decoration");
    QDir decorationDir(decorationPath);
    if (decorationDir.exists()) {
        QStringList typeDirectories = decorationDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        
        for (const QString &typeName : typeDirectories) {
            QString typePath = decorationDir.absoluteFilePath(typeName);
            QDir typeDir(typePath);
            
            QStringList filters;
            filters << "*.png" << "*.jpg" << "*.jpeg";
            QStringList imageFiles = typeDir.entryList(filters, QDir::Files);
            
            if (!imageFiles.isEmpty()) {
                result << QString("decoration/%1 (%2 images)").arg(typeName).arg(imageFiles.size());
            }
        }
    }
    
    // Scan player icons
    QString playerIconsPath = assetsDir.absoluteFilePath("player_icons");
    QDir playerIconsDir(playerIconsPath);
    if (playerIconsDir.exists()) {
        QStringList filters;
        filters << "*.png" << "*.jpg" << "*.jpeg";
        QStringList imageFiles = playerIconsDir.entryList(filters, QDir::Files);
        
        if (!imageFiles.isEmpty()) {
            result << QString("player_icons (%1 images)").arg(imageFiles.size());
        }
    }
    
    return result;
}
