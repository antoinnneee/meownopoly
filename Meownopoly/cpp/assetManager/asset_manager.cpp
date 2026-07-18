#include "assetManager/asset_manager.h"
#include <QDebug>
#include <QJsonParseError>
#include <QFileInfo>
#include <QQmlEngine>
#include <QDir>
#include <QDirIterator>
#include <QImageReader>
#include <QRandomGenerator>
#include <QUrl>
#include <QCryptographicHash>
#include <QRegularExpression>
#include "tools/metadata_generator.h"
#include "artifacts/artifact_registry.h"

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
    case TagsRole:
        return asset.tags;
    case DescriptionRole:
        return asset.description;
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
    roles[TagsRole] = "tags";
    roles[DescriptionRole] = "description";
    return roles;
}

void AssetModel::addAsset(const QString &path, const QString &type, const QString &category,
                         int ratioWidth, int ratioHeight, int width, int height, const QString &id, const QString &filename,
                         const QString &extension, bool animated, int frameCount,
                         const QStringList &tags, const QString &description)
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
    asset.tags = tags;
    asset.description = description;
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
    // Ownership explicite pour QML — évite fuite mémoire si le modèle est réassigné
    QQmlEngine::setObjectOwnership(filteredModel, QQmlEngine::JavaScriptOwnership);

    int matchCount = 0;
    for (const Asset &asset : m_assets) {
        if (asset.type == type) {
            filteredModel->addAsset(asset.path, asset.type, asset.category,
                                  asset.ratioWidth, asset.ratioHeight, asset.width, asset.height,
                                  asset.id, asset.filename, asset.extension, asset.animated, asset.frameCount,
                                  asset.tags, asset.description);
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
    if (category.isEmpty() || type.isEmpty()) {
        ASSET_ERROR("Invalid parameters - category:" << category << "type:" << type);
        return nullptr;
    }

    QString key = category + "_" + type;
    ASSET_DEBUG("Looking for key:" << key);

    auto it = m_models.find(key);
    if (it != m_models.end()) {
        AssetModel* existingModel = it.value();
        if (existingModel && existingModel->parent()) {
            ASSET_INFO("Found existing model with" << existingModel->rowCount() << "assets");
            return existingModel;
        }
        // Modèle invalide, le supprimer du cache
        ASSET_ERROR("Removing invalid model from cache for key:" << key);
        if (existingModel) {
            existingModel->deleteLater();
        }
        m_models.erase(it);
    }

    AssetModel *newModel = new AssetModel(this);
    m_models.insert(key, newModel);
    ASSET_INFO("Created empty model for category:" << category);
    return newModel;
}

// Helper function to create a fallback Asset
Asset createFallbackAsset()
{
    Asset fallback;
    fallback.path = QStringLiteral("qrc:/asset/nopic.webp");
    fallback.type = QStringLiteral("fallback");
    fallback.category = QStringLiteral("system");
    fallback.ratioWidth = 1;
    fallback.ratioHeight = 1;
    fallback.width = 256;
    fallback.height = 256;
    fallback.id = QStringLiteral("nopic");
    fallback.filename = QStringLiteral("nopic.webp");
    fallback.extension = QStringLiteral("webp");
    fallback.animated = false;
    fallback.frameCount = 1;
    fallback.tags = {};
    fallback.description = QString();
    return fallback;
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
    return createFallbackAsset(); // Retourne l'asset fallback si non trouvé
}

Asset AssetModel::getAssetByFilename(const QString &filename) const
{
    for (const Asset &asset : m_assets) {
        if (asset.filename == filename) {
            return asset;
        }
    }
    ASSET_ERROR("Asset not found with filename:" << filename);
    return createFallbackAsset(); // Retourne l'asset fallback si non trouvé
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
    map["tags"] = asset.tags;
    map["description"] = asset.description;
    return map;
}

// Helper function to create a fallback asset QVariantMap
QVariantMap createFallbackAssetMap(const QString &defaultPath)
{
    QVariantMap map;
    map["path"] = defaultPath;
    map["type"] = "fallback";
    map["category"] = "system";
    map["ratioWidth"] = 1;
    map["ratioHeight"] = 1;
    map["width"] = 256;
    map["height"] = 256;
    map["id"] = "nopic";
    map["filename"] = "nopic.webp";
    map["extension"] = "webp";
    map["animated"] = false;
    map["frameCount"] = 1;
    map["tags"] = QStringList();
    map["description"] = QString();
    return map;
}

// Implémentation des méthodes de AssetManager
QVariantMap AssetManager::getAssetByFilename(const QString &category, const QString &type, const QString &filename)
{
    ASSET_DEBUG("Getting asset by filename:" << category << type << filename);
    
    AssetModel *model = getAssetModel(category, type);
    if (model == nullptr) {
        ASSET_ERROR("No model found for" << category << type << ", returning fallback");
        return createFallbackAssetMap(getDefaultAssetPath());
    }
    
    Asset asset = model->getAssetByFilename(filename);
    
    // Si l'asset n'est pas trouvé (id vide), retourner le fallback
    if (asset.id.isEmpty()) {
        ASSET_ERROR("Asset not found with filename:" << filename << ", returning fallback");
        return createFallbackAssetMap(getDefaultAssetPath());
    }
    
    return assetToVariantMap(asset);
}

QVariantMap AssetManager::getAssetById(const QString &category, const QString &type, const QString &id)
{
    ASSET_DEBUG("Getting asset by id:" << category << type << id);
    
    AssetModel *model = getAssetModel(category, type);
    if (model == nullptr) {
        ASSET_ERROR("No model found for" << category << type << ", returning fallback");
        return createFallbackAssetMap(getDefaultAssetPath());
    }
    
    Asset asset = model->getAssetById(id);
    
    // Si l'asset n'est pas trouvé (id vide), retourner le fallback
    if (asset.id.isEmpty()) {
        ASSET_ERROR("Asset not found with id:" << id << ", returning fallback");
        return createFallbackAssetMap(getDefaultAssetPath());
    }
    
    return assetToVariantMap(asset);
}

QVariantMap AssetManager::getRandomAsset(const QString &category, const QString &type)
{
    ASSET_DEBUG("Getting random asset for:" << category << type);
    
    AssetModel *model = getAssetModel(category, type);
    if (model == nullptr) {
        ASSET_ERROR("No model found for" << category << type << ", returning fallback");
        return createFallbackAssetMap(getDefaultAssetPath());
    }
    
    int rowCount = model->rowCount();
    if (rowCount == 0) {
        ASSET_ERROR("Model is empty for" << category << type << ", returning fallback");
        return createFallbackAssetMap(getDefaultAssetPath());
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
    
    ASSET_ERROR("Failed to retrieve asset at index" << randomIndex << ", returning fallback");
    return createFallbackAssetMap(getDefaultAssetPath());
}

QString AssetManager::getAssetPath(const QString &category, const QString &type, const QString &id)
{
    ASSET_DEBUG("Requesting" << category << type << id);

    AssetModel *model = getAssetModel(category, type);
    if (model == nullptr) {
        ASSET_ERROR("Asset not valid, returning fallback for" << category << type << id);
        return getDefaultAssetPath();
    }
    
    Asset asset = model->getAssetById(id);
    
    // Si l'asset n'est pas trouvé (id vide), retourner le fallback
    if (asset.id.isEmpty()) {
        ASSET_ERROR("Asset not found, returning fallback for" << category << type << id);
        return getDefaultAssetPath();
    }

    return asset.path;
}

QString AssetManager::getAnimatedGifPath(const QString &category, const QString &type, const QString &id)
{
    ASSET_DEBUG("Getting animated GIF path for category:" << category << "type:" << type << "id:" << id);

    QString animatedPath = buildAssetPath(category, type, id + "-animated.webp");

    QString localPath = QUrl(animatedPath).toLocalFile();
    if (!QFile::exists(localPath)) {
        ASSET_ERROR("Animated asset not found:" << animatedPath << ", returning fallback");
        return getDefaultAssetPath();
    }

    return animatedPath;
}

void AssetManager::reloadAssets()
{
    ASSET_DEBUG("Forcing asset reload...");
    loadAssets();
}

QString AssetManager::getDefaultAssetPath() const
{
    return QStringLiteral("qrc:/asset/nopic.webp");
}


void AssetManager::loadAssets()
{
    ASSET_INFO("Starting asset loading...");

    // Supprimer tous les modèles existants
    for (auto it = m_models.begin(); it != m_models.end(); ++it) {
        if (it.value()) {
            it.value()->deleteLater();
        }
    }
    m_models.clear();
    m_imageCache.clear();

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

    // Charger tags.json pour cette catégorie
    QHash<QString, QPair<QStringList, QString>> tagsData;
    QString tagsFilePath = categoryDir.absoluteFilePath("tags.json");
    QFile tagsFile(tagsFilePath);
    if (tagsFile.open(QIODevice::ReadOnly)) {
        QJsonParseError parseError;
        QJsonDocument tagsDoc = QJsonDocument::fromJson(tagsFile.readAll(), &parseError);
        if (parseError.error == QJsonParseError::NoError) {
            QJsonObject tagsObj = tagsDoc.object();
            for (auto it = tagsObj.begin(); it != tagsObj.end(); ++it) {
                QJsonObject entry = it.value().toObject();
                QStringList tags;
                for (const QJsonValue &tag : entry["tags"].toArray()) {
                    tags.append(tag.toString());
                }
                QString description = entry["description"].toString();
                tagsData.insert(it.key(), {tags, description});
            }
        }
        tagsFile.close();
    }

    QStringList typeDirectories = categoryDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);

    for (const QString &typeName : typeDirectories) {
        QString typePath = categoryDir.absoluteFilePath(typeName);
        loadTypeFromDirectory(typePath, typeName, categoryName, tagsData);
    }
}

void AssetManager::loadTypeFromDirectory(const QString &typePath, const QString &typeName, const QString &categoryName, const QHash<QString, QPair<QStringList, QString>> &tagsData)
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

        // Rechercher les tags et description pour cet asset
        QStringList tags;
        QString description;
        QString tagsKey = typeName + "/" + filename;
        if (tagsData.contains(tagsKey)) {
            tags = tagsData[tagsKey].first;
            description = tagsData[tagsKey].second;
        }

        QString fullPath = buildAssetPath(categoryName, typeName, filename);

        // Vérifier que le fichier existe, sinon utiliser l'asset par défaut
        QString localPath = QUrl(fullPath).toLocalFile();
        if (!QFile::exists(localPath)) {
            ASSET_ERROR("Asset file not found:" << localPath << ", using fallback");
            fullPath = getDefaultAssetPath();
        }

        // Récupérer ou créer le modèle pour cette catégorie/type
        QString key = categoryName + "_" + typeName;
        AssetModel *targetModel = m_models.value(key, nullptr);

        if (!targetModel) {
            targetModel = new AssetModel(this);
            m_models.insert(key, targetModel);
            ASSET_INFO("Created new model for" << key);
        }

        targetModel->addAsset(fullPath, typeName, categoryName, ratioWidth, ratioHeight, width, height, id, filename, extension, animated, frameCount, tags, description);
    }
}


QString AssetManager::buildAssetPath(const QString &category, const QString &type, const QString &filename) const
{
    QDir assetsDir(m_assetsBasePath);
    QString localPath;
    if (type.isEmpty()) {
        localPath = assetsDir.absoluteFilePath(category + "/" + filename);
    } else {
        localPath = assetsDir.absoluteFilePath(category + "/" + type + "/" + filename);
    }
    return QUrl::fromLocalFile(localPath).toString();
}

bool AssetManager::generateMetadataForDirectory(const QString &directoryPath)
{
    return MetadataGenerator::generateMetadataForDirectory(directoryPath);
}

bool AssetManager::generateAllMetadata()
{
    bool success = MetadataGenerator::generateAllMetadata(m_assetsBasePath);

    // Reload assets after generation
    if (success) {
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

    // Utiliser les catégories déjà chargées, ou scanner le dossier directement
    QStringList categories = m_categories.isEmpty()
        ? assetsDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)
        : m_categories;

    for (const QString &category : categories) {
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
        backgrounds.append(QUrl::fromLocalFile(fileInfo.absoluteFilePath()).toString());
    }
    
    return backgrounds;
}

bool AssetManager::isTransparent(float px, float py, QString path)
{
    QString localPath = path.startsWith("file:") ? QUrl(path).toLocalFile() : path;

    // Utiliser le cache d'images pour éviter de recharger à chaque appel
    if (!m_imageCache.contains(localPath)) {
        QImage image(localPath);
        if (image.isNull()) {
            ASSET_ERROR("Failed to load image:" << localPath);
            return false;
        }
        m_imageCache.insert(localPath, image);
    }

    const QImage &image = m_imageCache[localPath];
    int pixelX = static_cast<int>(image.width() / px);
    int pixelY = static_cast<int>(image.height() / py);

    if (pixelX < 0 || pixelX >= image.width() || pixelY < 0 || pixelY >= image.height())
        return true;

    QColor color = image.pixelColor(pixelX, pixelY);
    if (!color.isValid())
        return true;
    return (color.alpha() == 0);
}

QStringList AssetManager::getAvailableModels() const
{
    QStringList models;
    QString modelsPath = getAppDataPath() + "/models";
    QDir modelsDir(modelsPath);

    if (!modelsDir.exists()) {
        ASSET_ERROR("Models directory does not exist: " + modelsPath);
        return models;
    }

    // On liste les sous-répertoires, chacun représentant un modèle
    QStringList subDirs = modelsDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    return subDirs;
}

QStringList AssetManager::availablePlayerModels() const
{
    // Primitives toujours disponibles (utilisées en fallback par World3D).
    QStringList result;
    result << QStringLiteral("Cube") << QStringLiteral("Sphere");

    auto isValidModelDir = [](const QDir &dir) {
        const QString name = dir.dirName();
        if (name.isEmpty() || name.startsWith('.')) return false;
        // Format kura courant (Color ID Map) : model_manifest.json + base/<x>.glb,
        // sans <name>.qml (balsam abandonne, cf. Phase E). Format legacy balsam :
        // <name>.qml. On accepte les deux pour ne pas masquer les anciens modeles.
        return dir.exists(QStringLiteral("model_manifest.json"))
               || dir.exists(name + QStringLiteral(".qml"));
    };

    auto pushUnique = [&result](const QString &name) {
        if (!result.contains(name, Qt::CaseInsensitive)) result << name;
    };

    // 1) Built-in : scan QRC `:/asset/models/`. Si rien n'est embarqué (cas
    //    actuel du projet), QDirIterator retourne juste rien — pas d'erreur.
    {
        QDirIterator it(QStringLiteral(":/asset/models"),
                        QDir::Dirs | QDir::NoDotAndDotDot,
                        QDirIterator::NoIteratorFlags);
        while (it.hasNext()) {
            it.next();
            const QDir dir(it.filePath());
            if (isValidModelDir(dir)) pushUnique(dir.dirName());
        }
    }

    // 2) Téléchargés : `<AppData>/models/`.
    {
        const QString appData = getAppDataPath() + QStringLiteral("/models");
        QDir modelsDir(appData);
        if (modelsDir.exists()) {
            const QStringList subs = modelsDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
            for (const QString &sub : subs) {
                const QDir dir(modelsDir.absoluteFilePath(sub));
                if (isValidModelDir(dir)) pushUnique(sub);
            }
        }
    }

    return result;
}

QString AssetManager::getAppDataPath() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
}

// ==================== Artefacts par hash (D16/D36, plan T4-1/M8) ==========

bool AssetManager::isArtifactAvailable(const QString &contentHash) const
{
    return ArtifactRegistry::instance()->isAvailable(contentHash);
}

QString AssetManager::artifactBlobPath(const QString &contentHash) const
{
    // Chemin du blob dans le store adressé par hash (existe ou non).
    return ArtifactStore().pathForHash(contentHash);
}

QVariantMap AssetManager::artifactManifest(const QString &contentHash) const
{
    const ArtifactManifest m = ArtifactRegistry::instance()->manifest(contentHash);
    if (!m.isValid())
        return QVariantMap();
    return m.toJson().toVariantMap();
}

// ==================== Color ID Map (résolution runtime) ====================

// Garde lettres/chiffres/espace/-/_ (évite toute traversée de chemin).
static QString sanitizeColorIdName(const QString &name)
{
    QString out;
    for (const QChar c : name.trimmed()) {
        if (c.isLetterOrNumber() || c == QLatin1Char('_')
            || c == QLatin1Char('-') || c == QLatin1Char(' '))
            out += c;
    }
    return out.trimmed();
}

// Résout le dossier de version actif d'un package installé (M11). Si
// <baseDir>/installed.json existe et déclare layout "versioned" pointant vers
// une version présente sous versions/<v>/, renvoie ce sous-dossier. Sinon "".
// Rétro-compat : les modèles à plat (sans installed.json) ne sont pas affectés.
static QString activeVersionSubdir(const QString &baseDir)
{
    QFile f(baseDir + QStringLiteral("/installed.json"));
    if (!f.open(QIODevice::ReadOnly)) return QString();
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    f.close();
    if (!doc.isObject()) return QString();
    const QJsonObject obj = doc.object();
    if (obj.value(QStringLiteral("layout")).toString() != QStringLiteral("versioned"))
        return QString();
    const QString cur = obj.value(QStringLiteral("currentVersion")).toString();
    if (cur.isEmpty()) return QString();
    const QString sub = baseDir + QStringLiteral("/versions/") + cur;
    return QDir(sub).exists() ? sub : QString();
}

QString AssetManager::modelDir(const QString &modelName) const
{
    const QString safe = sanitizeColorIdName(modelName);
    if (safe.isEmpty()) return QString();
    const QString appData = getAppDataPath() + QStringLiteral("/models/") + safe;
    if (QDir(appData).exists()) {
        // Layout versionné M11 (installation atomique par dossier de version) —
        // n'intervient que si installed.json est présent (aucun modèle legacy).
        const QString versioned = activeVersionSubdir(appData);
        return versioned.isEmpty() ? appData : versioned;
    }
    const QString qrc = QStringLiteral(":/asset/models/") + safe;
    if (QDir(qrc).exists()) return qrc;
    return appData; // défaut (peut ne pas exister encore)
}

QVariantMap AssetManager::readModelManifest(const QString &modelName) const
{
    QVariantMap result;
    QFile f(modelDir(modelName) + QStringLiteral("/model_manifest.json"));
    if (!f.open(QIODevice::ReadOnly)) return result;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    f.close();
    if (!doc.isObject()) return result;
    const QJsonObject obj = doc.object();
    for (auto it = obj.begin(); it != obj.end(); ++it)
        result.insert(it.key(), it.value().toVariant());
    return result;
}

QStringList AssetManager::listModelSkins(const QString &modelName) const
{
    QDir d(modelDir(modelName) + QStringLiteral("/skins"));
    if (!d.exists()) return {};
    return d.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
}

QStringList AssetManager::listSkinTextures(const QString &modelName, const QString &skin) const
{
    QDir d(modelDir(modelName) + QStringLiteral("/skins/") + sanitizeColorIdName(skin)
           + QStringLiteral("/textures"));
    if (!d.exists()) return {};
    return d.entryList(QStringList{ "*.png", "*.jpg", "*.jpeg", "*.tga", "*.bmp" },
                       QDir::Files, QDir::Name);
}

QString AssetManager::readSkinJson(const QString &modelName, const QString &skin) const
{
    QFile f(modelDir(modelName) + QStringLiteral("/skins/") + sanitizeColorIdName(skin)
            + QStringLiteral("/skin.json"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return QString();
    const QString s = QString::fromUtf8(f.readAll());
    f.close();
    return s;
}

QStringList AssetManager::listSkinVariants(const QString &modelName, const QString &skin) const
{
    QDir d(modelDir(modelName) + QStringLiteral("/skins/") + sanitizeColorIdName(skin)
           + QStringLiteral("/variants"));
    if (!d.exists()) return {};
    QStringList names;
    for (const QString &f : d.entryList(QStringList{ "*.json" }, QDir::Files, QDir::Name))
        names << QFileInfo(f).completeBaseName();
    return names;
}

QString AssetManager::loadSkinVariant(const QString &modelName, const QString &skin,
                                      const QString &variant) const
{
    QFile f(modelDir(modelName) + QStringLiteral("/skins/") + sanitizeColorIdName(skin)
            + QStringLiteral("/variants/") + sanitizeColorIdName(variant) + QStringLiteral(".json"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return QString();
    const QString s = QString::fromUtf8(f.readAll());
    f.close();
    return s;
}

// ==================== Bibliothèque officielle V3 (M11, D18/D29/D38) ==========

// Vrai si `v` respecte un semver minimal MAJOR.MINOR.PATCH (préversion tolérée).
static bool isSemver(const QString &v)
{
    static const QRegularExpression re(
        QStringLiteral("^\\d+\\.\\d+\\.\\d+(?:[-+][0-9A-Za-z.-]+)?$"));
    return re.match(v).hasMatch();
}

QString AssetManager::computeFileHash(const QString &filePath) const
{
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly)) return QString();
    QCryptographicHash hash(QCryptographicHash::Sha256);
    if (!hash.addData(&f)) { f.close(); return QString(); }
    f.close();
    return QString::fromLatin1(hash.result().toHex());
}

QVariantMap AssetManager::readPackageManifest(const QString &modelName) const
{
    const QString dir = modelDir(modelName);
    if (dir.isEmpty()) return QVariantMap();

    // Format V3 natif.
    QFile f(dir + QStringLiteral("/package_manifest.json"));
    if (f.open(QIODevice::ReadOnly)) {
        const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
        f.close();
        if (doc.isObject()) return doc.object().toVariantMap();
    }

    // Rétro-compat : synthèse minimale depuis model_manifest.json (kind=asset3d).
    const QVariantMap legacy = readModelManifest(modelName);
    if (legacy.isEmpty()) return QVariantMap();

    QVariantMap out;
    out.insert(QStringLiteral("manifestVersion"), kPackageManifestVersion);
    out.insert(QStringLiteral("id"),
               legacy.value(QStringLiteral("name"), sanitizeColorIdName(modelName)));
    out.insert(QStringLiteral("version"),
               legacy.value(QStringLiteral("version"), QStringLiteral("0.0.0")));
    out.insert(QStringLiteral("kind"), QStringLiteral("asset3d"));
    out.insert(QStringLiteral("name"), legacy.value(QStringLiteral("name"), modelName));
    out.insert(QStringLiteral("synthesized"), true);
    // Champs de confiance réservés (D38, non vérifiés — R16).
    out.insert(QStringLiteral("signature"), QString());
    out.insert(QStringLiteral("publisherKeyId"), QString());
    return out;
}

QVariantMap AssetManager::validatePackageManifest(const QString &json) const
{
    QStringList errors;
    QStringList warnings;

    QJsonParseError perr{};
    const QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8(), &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject()) {
        errors << QStringLiteral("JSON invalide : %1").arg(perr.errorString());
        QVariantMap r;
        r.insert(QStringLiteral("ok"), false);
        r.insert(QStringLiteral("errors"), errors);
        r.insert(QStringLiteral("warnings"), warnings);
        return r;
    }
    const QJsonObject o = doc.object();

    // --- Identité (obligatoire) ---
    if (o.value(QStringLiteral("id")).toString().trimmed().isEmpty())
        errors << QStringLiteral("champ requis manquant : id");
    const QString ver = o.value(QStringLiteral("version")).toString();
    if (ver.isEmpty())
        errors << QStringLiteral("champ requis manquant : version");
    else if (!isSemver(ver))
        errors << QStringLiteral("version non semver : %1").arg(ver);

    static const QStringList kinds = { QStringLiteral("asset3d"),
                                       QStringLiteral("primitive"),
                                       QStringLiteral("module"),
                                       QStringLiteral("skin") };
    const QString kind = o.value(QStringLiteral("kind")).toString();
    if (kind.isEmpty())
        errors << QStringLiteral("champ requis manquant : kind");
    else if (!kinds.contains(kind))
        errors << QStringLiteral("kind inconnu : %1 (attendu asset3d|primitive|module|skin)").arg(kind);

    // --- Contenu : les primitives exigent un entryPoint ---
    if (kind == QStringLiteral("primitive")
        && o.value(QStringLiteral("entryPoint")).toString().trimmed().isEmpty())
        errors << QStringLiteral("primitive sans entryPoint");

    // --- Confiance : champs réservés, doivent exister (même vides) ---
    if (!o.contains(QStringLiteral("signature")))
        warnings << QStringLiteral("champ de confiance réservé absent : signature");
    if (!o.contains(QStringLiteral("publisherKeyId")))
        warnings << QStringLiteral("champ de confiance réservé absent : publisherKeyId");

    // --- Compat ---
    if (!o.contains(QStringLiteral("minGameVersion")))
        warnings << QStringLiteral("compat.minGameVersion absent");

    // --- Budgets provisoires (D38) — vérifiés au niveau du manifeste ---
    const QJsonObject budgets = o.value(QStringLiteral("budgets")).toObject();
    const double sizeMb = budgets.value(QStringLiteral("packageSizeBytes")).toDouble()
                          / (1024.0 * 1024.0);
    if (sizeMb > 20.0)
        errors << QStringLiteral("budget dépassé : package %1 Mo > 20 Mo").arg(sizeMb, 0, 'f', 1);
    const int tris = budgets.value(QStringLiteral("triangles")).toInt();
    if (tris > 50000)
        errors << QStringLiteral("budget dépassé : %1 triangles > 50000").arg(tris);
    else if (tris > 10000)
        warnings << QStringLiteral("%1 triangles > 10000 recommandé (posable en nombre)").arg(tris);
    const int tex = budgets.value(QStringLiteral("maxTextureSize")).toInt();
    if (tex > 2048)
        errors << QStringLiteral("budget dépassé : texture %1² > 2048²").arg(tex);

    QVariantMap r;
    r.insert(QStringLiteral("ok"), errors.isEmpty());
    r.insert(QStringLiteral("errors"), errors);
    r.insert(QStringLiteral("warnings"), warnings);
    return r;
}

QVariantMap AssetManager::resolveModelReference(const QString &modelName,
                                                const QString &version,
                                                const QString &contentHash) const
{
    QVariantMap r;
    const QString dir = modelDir(modelName);
    const QVariantMap manifest = readPackageManifest(modelName);
    const QString installedVersion = manifest.value(QStringLiteral("version")).toString();
    const QString installedHash =
        manifest.value(QStringLiteral("contentHash")).toString();

    const bool present = !dir.isEmpty() && QDir(dir).exists();
    const bool versionMatch = version.isEmpty() || version == installedVersion;
    const bool hashMatch = contentHash.isEmpty()
                           || (!installedHash.isEmpty() && contentHash == installedHash);

    QString diagnostic;
    if (!present)
        diagnostic = QStringLiteral("modèle absent : %1").arg(modelName);
    else if (!versionMatch)
        diagnostic = QStringLiteral("version %1 requise, installée %2")
                         .arg(version, installedVersion);
    else if (!hashMatch)
        diagnostic = QStringLiteral("hash de contenu divergent pour %1").arg(modelName);

    r.insert(QStringLiteral("available"), present && versionMatch && hashMatch);
    r.insert(QStringLiteral("dir"), dir);
    r.insert(QStringLiteral("installedVersion"), installedVersion);
    r.insert(QStringLiteral("installedHash"), installedHash);
    r.insert(QStringLiteral("versionMatch"), versionMatch);
    r.insert(QStringLiteral("hashMatch"), hashMatch);
    r.insert(QStringLiteral("diagnostic"), diagnostic);
    return r;
}

QVariantMap AssetManager::verifyPackageIntegrity(const QString &modelName) const
{
    QVariantMap r;
    QStringList mismatches;
    QStringList missing;
    int checked = 0;

    const QString dir = modelDir(modelName);
    const QVariantMap manifest = readPackageManifest(modelName);
    // Le manifeste porte les hashes par fichier dans "files": { relPath: sha256 }.
    const QVariantMap files = manifest.value(QStringLiteral("files")).toMap();

    for (auto it = files.constBegin(); it != files.constEnd(); ++it) {
        const QString rel = it.key();
        const QString expected = it.value().toString();
        const QString abs = dir + QStringLiteral("/") + rel;
        if (!QFile::exists(abs)) { missing << rel; continue; }
        ++checked;
        const QString actual = computeFileHash(abs);
        if (actual.compare(expected, Qt::CaseInsensitive) != 0)
            mismatches << rel;
    }

    r.insert(QStringLiteral("ok"), mismatches.isEmpty() && missing.isEmpty());
    r.insert(QStringLiteral("checked"), checked);
    r.insert(QStringLiteral("mismatches"), mismatches);
    r.insert(QStringLiteral("missing"), missing);
    return r;
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

// Supprime les accents/diacritiques d'une chaîne pour une recherche insensible aux accents
static QString removeAccents(const QString &str)
{
    QString normalized = str.normalized(QString::NormalizationForm_D);
    QString result;
    result.reserve(normalized.size());
    for (const QChar &ch : normalized) {
        if (ch.category() != QChar::Mark_NonSpacing)
            result.append(ch);
    }
    return result;
}

bool AssetManager::hasMatchingAsset(const QString &category, const QString &type, const QString &searchText)
{
    if (category.isEmpty() || type.isEmpty() || searchText.isEmpty())
        return false;

    AssetModel *model = getAssetModel(category, type);
    if (!model)
        return false;

    const QString searchNorm = removeAccents(searchText.toLower());
    for (const Asset &asset : model->getAssetList()) {
        // Chercher dans l'id et le filename
        if (removeAccents(asset.id.toLower()).contains(searchNorm) ||
            removeAccents(asset.filename.toLower()).contains(searchNorm))
            return true;
        // Chercher dans la description
        if (removeAccents(asset.description.toLower()).contains(searchNorm))
            return true;
        // Chercher dans les tags
        for (const QString &tag : asset.tags) {
            if (removeAccents(tag.toLower()).contains(searchNorm))
                return true;
        }
    }
    return false;
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

    for (auto it = m_models.begin(); it != m_models.end(); ) {
        AssetModel* model = it.value();
        if (!model || !model->parent()) {
            ASSET_ERROR("Removing invalid model for key:" << it.key());
            if (model) {
                model->deleteLater();
            }
            it = m_models.erase(it);
        } else {
            ++it;
        }
    }

    ASSET_INFO("Cleanup complete. Remaining models:" << m_models.size());
}
