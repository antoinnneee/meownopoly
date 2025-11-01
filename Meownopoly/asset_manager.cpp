#include "asset_manager.h"
#include <QDebug>
#include <QJsonParseError>
#include <QFileInfo>
#include <QQmlEngine>
#include <QDir>
#include <QImageReader>
#include <QRandomGenerator>
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
    case ExtensionRole:
        return asset.extension;
    case AnimatedRole:
        return asset.animated;
    case FrameCountRole:
        return asset.frameCount;
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
    roles[ExtensionRole] = "extension";
    roles[AnimatedRole] = "animated";
    roles[FrameCountRole] = "frameCount";
    return roles;
}

void AssetModel::addAsset(const QString &path, const QString &type, const QString &category,
                         int ratioWidth, int ratioHeight, int width, int height, const QString &id, const QString &filename, 
                         const QString &extension, bool animated, int frameCount)
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
    asset.extension = extension;
    asset.animated = animated;
    asset.frameCount = frameCount;
    m_assets.append(asset);
    endInsertRows();
}

void AssetModel::clear()
{
    ASSET_DEBUG("clear model");
    beginResetModel();
    m_assets.clear();
    endResetModel();
}

AssetModel* AssetModel::createFilteredModel(const QString &type) const
{
    if (type.isEmpty()) {
        ASSET_ERROR("Type parameter is empty");
        return nullptr;
    }

    AssetModel *filteredModel = new AssetModel();
    if (!filteredModel) {
        ASSET_ERROR("Failed to create filtered model");
        return nullptr;
    }

    int matchCount = 0;
    for (const Asset &asset : m_assets) {
        if (asset.type == type) {
            filteredModel->addAsset(asset.path, asset.type, asset.category,
                                  asset.ratioWidth, asset.ratioHeight, asset.width, asset.height,
                                  asset.id, asset.filename, asset.extension, asset.animated, asset.frameCount);
            matchCount++;
        }
    }

    ASSET_INFO("Created filtered model for type" << type << "with" << matchCount << "assets");

    return filteredModel;
}

// AssetManager Implementation
AssetManager::AssetManager(QObject *parent)
    : QObject(parent)
{
    m_assetsBasePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/assets/";
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

AssetModel* AssetManager::getAssetModel(const QString &category, const QString &type)
{
    // Vérification des paramEtres
    if (category.isEmpty() || type.isEmpty()) {
        ASSET_ERROR("Invalid parameters - category:" << category << "type:" << type);
        return nullptr;
    }

    QString key = category + "_" + type;
    ASSET_DEBUG("Looking for key:" << key);

    // Vérifier si le modèle filtré existe déj�
    for (int i = m_models.size() - 1; i >= 0; --i) { // Parcourir à l'envers pour éviter les problèmes d'index
        if (m_models[i].first == key) {
            AssetModel* existingModel = m_models[i].second;
                    if (existingModel && existingModel->parent()) { // Vérifier que le pointeur est valide
            ASSET_INFO("Found existing model with" << existingModel->rowCount() << "assets");
            return existingModel;
        } else {
            // Le modèle existe mais est null ou invalide, le supprimer du cache
            ASSET_ERROR("Removing invalid model from cache for key:" << key);
                if (existingModel) {
                    existingModel->deleteLater(); // Suppression sécurisée
                }
                m_models.removeAt(i);
                break;
            }
        }
    }

    AssetModel *filteredModel = nullptr;

    filteredModel = new AssetModel(this); // Avec parent directement
    if (filteredModel) {
        m_models.append(QPair<QString, AssetModel*>(key, filteredModel));
        ASSET_INFO("Created empty model for category:" << category);
    }
    return filteredModel;
}

// Implémentation des méthodes de AssetModel pour accéder directement aux assets
Asset AssetModel::getAssetById(const QString &id) const
{
    for (const Asset &asset : m_assets) {
        if (asset.id == id) {
            return asset;
        }
    }
    ASSET_ERROR("Asset not found with id:" << id);
    return Asset(); // Retourne un asset vide si non trouvé
}

Asset AssetModel::getAssetByFilename(const QString &filename) const
{
    for (const Asset &asset : m_assets) {
        if (asset.filename == filename) {
            return asset;
        }
    }
    ASSET_ERROR("Asset not found with filename:" << filename);
    return Asset(); // Retourne un asset vide si non trouvé
}

// Helper function to convert Asset to QVariantMap for QML
QVariantMap assetToVariantMap(const Asset &asset)
{
    QVariantMap map;
    map["path"] = asset.path;
    map["type"] = asset.type;
    map["category"] = asset.category;
    map["ratioWidth"] = asset.ratioWidth;
    map["ratioHeight"] = asset.ratioHeight;
    map["width"] = asset.width;
    map["height"] = asset.height;
    map["id"] = asset.id;
    map["filename"] = asset.filename;
    map["extension"] = asset.extension;
    map["animated"] = asset.animated;
    map["frameCount"] = asset.frameCount;
    return map;
}

// Implémentation des méthodes de AssetManager
QVariantMap AssetManager::getAssetByFilename(const QString &category, const QString &type, const QString &filename)
{
    ASSET_DEBUG("Getting asset by filename:" << category << type << filename);
    
    AssetModel *model = getAssetModel(category, type);
    if (model == nullptr) {
        ASSET_ERROR("No model found for" << category << type);
        return QVariantMap();
    }
    
    Asset asset = model->getAssetByFilename(filename);
    return assetToVariantMap(asset);
}

QVariantMap AssetManager::getAssetById(const QString &category, const QString &type, const QString &id)
{
    ASSET_DEBUG("Getting asset by id:" << category << type << id);
    
    AssetModel *model = getAssetModel(category, type);
    if (model == nullptr) {
        ASSET_ERROR("No model found for" << category << type);
        return QVariantMap();
    }
    
    Asset asset = model->getAssetById(id);
    //qDebug()<< asset.path;
    return assetToVariantMap(asset);
}

QVariantMap AssetManager::getRandomAsset(const QString &category, const QString &type)
{
    ASSET_DEBUG("Getting random asset for:" << category << type);
    
    AssetModel *model = getAssetModel(category, type);
    if (model == nullptr) {
        ASSET_ERROR("No model found for" << category << type);
        return QVariantMap();
    }
    
    int rowCount = model->rowCount();
    if (rowCount == 0) {
        ASSET_ERROR("Model is empty for" << category << type);
        return QVariantMap();
    }
    
    // Générer un index aléatoire entre 0 et rowCount - 1
    int randomIndex = QRandomGenerator::global()->bounded(rowCount);
    
    ASSET_DEBUG("Selected random index:" << randomIndex << "out of" << rowCount << "assets");
    
    // Récupérer l'asset depuis le modèle
    QList<Asset> assets = model->getAssetList();
    if (randomIndex >= 0 && randomIndex < assets.size()) {
        Asset asset = assets.at(randomIndex);
        return assetToVariantMap(asset);
    }
    
    ASSET_ERROR("Failed to retrieve asset at index" << randomIndex);
    return QVariantMap();
}

QString AssetManager::getAssetPath(const QString &category, const QString &type, const QString &id)
{
    ASSET_DEBUG("Requesting" << category << type << id);

    
    AssetModel *model = getAssetModel(category, type);
    if (model == nullptr) {
        ASSET_ERROR("Asset not valid, returning empty path for" << category << type << id);
        return "";
    }
    
    Asset asset = model->getAssetById(id);

    return asset.path;
}

QString AssetManager::getAnimatedGifPath(const QString &category, const QString &type, const QString &id)
{
    return buildAssetPath(category, type, id + "-animated.webp");
}

void AssetManager::reloadAssets()
{
    ASSET_DEBUG("Forcing asset reload...");
    loadAssets();
}


void AssetManager::loadAssets()
{
    ASSET_INFO("Starting asset loading...");


    // Clear filtered models cache
    cleanupInvalidModels(); // Nettoyer d'abord les modèles invalides
    for (const QPair<QString, AssetModel*> &pair : m_models) {
        if (pair.second) {
            pair.second->deleteLater(); // Suppression sécurisée
        }
    }
    m_models.clear();

    QDir assetsDir(m_assetsBasePath);
    if (!assetsDir.exists()) {
        ASSET_ERROR("Assets directory does not exist:" << m_assetsBasePath);
        return;
    }

    QStringList categories = assetsDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    if (categories.isEmpty()) {
        ASSET_ERROR("No categories found in" << m_assetsBasePath);
    }

    setCategories(categories);
    ASSET_INFO("Categories found:" << categories);

    for (const QString &category : categories) {
        QString categoryPath = assetsDir.absoluteFilePath(category); // basePath/category
        loadCategory(categoryPath, category);
    }

    ASSET_INFO("Assets loaded successfully");
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
        ASSET_ERROR("Cannot open metadata file:" << metadataPath);
        return;
    }

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(metadataFile.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        ASSET_ERROR("JSON parse error in" << metadataPath << ":" << parseError.errorString());
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
        
        // Extraire l'extension du filename
        QString extension = assetObj["extension"].toString();
        if (extension.isEmpty()) {
            // Si pas dans le JSON, extraire du filename
            QFileInfo fileInfo(filename);
            extension = fileInfo.suffix();
            if (extension.isEmpty()) {
                extension = "png"; // Valeur par défaut
            }
        }
        
        // Charger les informations d'animation
        bool animated = assetObj["animated"].toBool(false);
        int frameCount = assetObj["frameCount"].toInt(1);

        QString fullPath = buildAssetPath(categoryName, typeName, filename);

        // Add to appropriate model
        // todo: select model from variable, list with type and model
        AssetModel *targetModel = nullptr;

        QString key = categoryName + "_" + typeName;
        targetModel = nullptr;

        // Chercher le modèle existant
        for (const QPair<QString, AssetModel*> &pair : m_models) {
            if (pair.first == key) {
                targetModel = pair.second;
                // Vérifier que le modèle est toujours valide
                if (targetModel && targetModel->parent()) {
                    break;
                } else {
                    // Modèle invalide, on va en créer un nouveau
                    targetModel = nullptr;
                    break;
                }
            }
        }

        // Créer un nouveau modèle si pas trouvé ou invalide
        if (!targetModel) {
            targetModel = new AssetModel(this); // Avec parent pour gestion mémoire
            m_models.append(QPair<QString, AssetModel*>(key, targetModel));
            ASSET_INFO("Created new model for" << key);
        }


        if (targetModel) {
            targetModel->addAsset(fullPath, typeName, categoryName, ratioWidth, ratioHeight, width, height, id, filename, extension, animated, frameCount);
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
        ASSET_ERROR("Directory does not exist:" << directoryPath);
        return false;
    }

    // Get all PNG files in the directory
    QStringList filters;
    filters << "*.png" << "*.jpg" << "*.jpeg" << "*.webp";  // maybe not work with other than png
    QStringList imageFiles = dir.entryList(filters, QDir::Files);

    if (imageFiles.isEmpty()) {
        ASSET_ERROR("No image files found in:" << directoryPath);
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
            ASSET_ERROR("Cannot read image dimensions for:" << fullPath);
            continue;
        }

        // Generate ID from filename (remove extension)
        QFileInfo fileInfo(filename);
        QString id = fileInfo.baseName();
        QString extension = fileInfo.suffix();
        
        // Detect animation (important: reader already read the file, use it)
        bool isAnimated = reader.supportsAnimation() && reader.imageCount() > 1;
        int frameCount = isAnimated ? reader.imageCount() : 1;
        
        ASSET_INFO("Processing" << filename << "- Animated:" << isAnimated << "Frames:" << frameCount);

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
        assetObj["extension"] = extension;
        assetObj["animated"] = isAnimated;
        assetObj["frameCount"] = frameCount;
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
        ASSET_ERROR("Cannot create metadata file:" << metadataPath);
        return false;
    }

    QJsonDocument doc(metadataObj);
    metadataFile.write(doc.toJson());
    metadataFile.close();

    ASSET_INFO("Generated metadata for" << imageFiles.size() << "assets in:" << directoryPath);
    ASSET_INFO("Metadata saved to:" << metadataPath);

    return true;
}

bool AssetManager::generateAllMetadata()
{
    QDir assetsDir(m_assetsBasePath);
    if (!assetsDir.exists()) {
        ASSET_ERROR("Assets base directory does not exist:" << m_assetsBasePath);
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

    ASSET_INFO("Generated metadata for" << generatedCount << "directories");

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
                filters << "*.png" << "*.jpg" << "*.jpeg" << "*.webp";
                QStringList imageFiles = typeDir.entryList(filters, QDir::Files);
                if (!imageFiles.isEmpty()) {
                    result << QString("%1/%2 (%3 images)").arg(category).arg(typeName).arg(imageFiles.size());
                }
            }
        }
    }

    return result;
}

QStringList AssetManager::getAvailableBackgrounds() const
{
    QStringList backgrounds;
    QString backgroundPath = m_assetsBasePath + "/background";
    QDir directory(backgroundPath);
    
    // Vérifier que le dossier existe
    if (!directory.exists()) {
        ASSET_ERROR("Background directory does not exist: " + backgroundPath);
        return backgrounds;
    }
    
    // Configurer les filtres pour les fichiers d'image
    QStringList filters;
    filters << "*.png" << "*.jpg" << "*.jpeg" << "*.webp";
    directory.setNameFilters(filters);
    directory.setFilter(QDir::Files | QDir::NoDotAndDotDot);
    
    // Récupérer la liste des fichiers avec leurs chemins absolus
    QFileInfoList fileList = directory.entryInfoList();
    for (const QFileInfo &fileInfo : fileList) {
        // Ajouter le chemin absolu avec le préfixe file:///
        backgrounds.append("file:///" + fileInfo.absoluteFilePath());
    }
    
    return backgrounds;
}

bool AssetManager::isTransparent(float px, float py, QString path)
{
    if (path.startsWith("file:///"))
        path = path.right(path.length() - 8);
    QImage image(path);
    if (image.isNull()) {
        ASSET_ERROR("Failed to load image:" << path);
        return false; // or true, depending on how you want to handle errors
    }

    QColor color = image.pixelColor(image.width()/px, image.height()/py);
    if (!color.isValid())
        return true;
    return (color.alpha() == 0);
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
        filters << "*.png" << "*.jpg" << "*.jpeg" << "*.webp";
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

bool AssetManager::isAssetValid(const QString &category, const QString &type, const QString &id)
{
    // Vérifications de base
    if (category.isEmpty() || type.isEmpty() || id.isEmpty()) {
        ASSET_ERROR("Invalid parameters - category:" << category << "type:" << type << "id:" << id);
        return false;
    }

    AssetModel* model = getAssetModel(category, type);
    if (!model) {
        ASSET_ERROR("No model found for" << category << type);
        return false;
    }

    // Vérifier que le modèle est toujours valide
    if (!model->parent()) {
        ASSET_ERROR("Model has no parent, potentially invalid");
        return false;
    }

    int rowCount = model->rowCount();
    ASSET_DEBUG("Searching for id" << id << "in model with" << rowCount << "assets");

    for (int i = 0; i < rowCount; i++) {
        QModelIndex index = model->index(i, 0);
        if (!index.isValid()) {
            ASSET_ERROR("Invalid index at row" << i);
            continue;
        }

        QVariant idData = model->data(index, AssetModel::IdRole);
        if (idData.toString() == id) {
            ASSET_INFO("Found asset" << id << "at row" << i);
            return true;
        }
    }

    ASSET_DEBUG("Asset" << id << "not found in" << category << type);
    return false;
}

void AssetManager::cleanupInvalidModels()
{
    ASSET_DEBUG("Cleaning up invalid models...");

    for (int i = m_models.size() - 1; i >= 0; --i) {
        AssetModel* model = m_models[i].second;
        if (!model || !model->parent()) {
            ASSET_ERROR("Removing invalid model for key:" << m_models[i].first);
            if (model) {
                model->deleteLater();
            }
            m_models.removeAt(i);
        }
    }

    ASSET_INFO("Cleanup complete. Remaining models:" << m_models.size());
}
