#ifndef ASSET_MANAGER_H
#define ASSET_MANAGER_H

#include <QObject>
#include <QAbstractListModel>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QQmlEngine>
#include <QImageReader>
#include <QJsonDocument>
#include <QHash>
#include <QUrl>

// Debug defines
#define ENABLE_ASSET_DEBUG 0

#if ENABLE_ASSET_DEBUG
    #define ASSET_DEBUG(msg) qDebug() << "[ASSET_DEBUG]" << msg
    #define ASSET_INFO(msg) qDebug() << "\033[34m[ASSET_INFO]\033[0m" << msg << Q_FUNC_INFO
    #define ASSET_ERROR(msg) qWarning() << "\033[31m[ASSET_ERROR]\033[0m" << msg << Q_FUNC_INFO
#else
    #define ASSET_DEBUG(msg)
    #define ASSET_INFO(msg)
    #define ASSET_ERROR(msg)
#endif

struct Asset {
    QString path;
    QString type;
    QString category;
    int ratioWidth;
    int ratioHeight;
    int width;
    int height;
    QString id;
    QString filename;
    QString extension;
    bool animated;
    int frameCount;
    QStringList tags;
    QString description;
};

class AssetModel : public QAbstractListModel
{
    Q_OBJECT

private:
    QList<Asset> m_assets;

public:
    enum AssetRoles {
        PathRole = Qt::UserRole + 1,
        TypeRole,
        CategoryRole,
        RatioWidthRole,
        RatioHeightRole,
        WidthRole,
        HeightRole,
        IdRole,
        FilenameRole,
        ExtensionRole,
        AnimatedRole,
        FrameCountRole,
        TagsRole,
        DescriptionRole
    };

    explicit AssetModel(QObject *parent = nullptr);

    // QAbstractListModel interface
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Asset management
    void addAsset(const QString &path, const QString &type, const QString &category,
                  int ratioWidth, int ratioHeight, int width, int height, const QString &id, const QString &filename,
                  const QString &extension = "png", bool animated = false, int frameCount = 1,
                  const QStringList &tags = {}, const QString &description = "");
    void clear();
    
    // Filtering
    Q_INVOKABLE AssetModel* createFilteredModel(const QString &type) const;

    // Direct access to assets
    QList<Asset> getAssetList() const {return m_assets;}
    Asset getAssetById(const QString &id) const;
    Asset getAssetByFilename(const QString &filename) const;

};

class AssetManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList categories READ categories NOTIFY categoriesChanged)
    Q_PROPERTY(QString assetsBasePath READ assetsBasePath NOTIFY assetsBasePathChanged)

public:
    explicit AssetManager(QObject *parent = nullptr);
    static void registerQml();
    static AssetManager* instance();
    static QObject* qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    // Property getters
    QString assetsBasePath() const { return m_assetsBasePath; }
    
    /**
     * @brief Construit le chemin complet d'un asset
     * @param category Catégorie de l'asset (ex: "decoration")
     * @param type Type de l'asset (ex: "grass")
     * @param filename Nom du fichier avec extension
     * @return Chemin complet avec préfixe file:///
     */
    Q_INVOKABLE QString buildAssetPath(const QString &category, const QString &type, const QString &filename) const;
    
    /**
     * @brief Récupère le chemin d'un asset par son ID
     * @param category Catégorie de l'asset
     * @param type Type de l'asset
     * @param id Identifiant de l'asset (sans extension)
     * @return Chemin complet ou chaîne vide si non trouvé
     * @note Utilise l'extension stockée dans les métadonnées
     */
    Q_INVOKABLE QString getAssetPath(const QString &category, const QString &type, const QString &id);

    /**
     * @brief Récupère le chemin d'un GIF animé
     * @param category Catégorie de l'asset
     * @param type Type de l'asset
     * @param id Identifiant de l'asset
     * @return Chemin vers le fichier -animated.webp
     */
    Q_INVOKABLE QString getAnimatedGifPath(const QString &category, const QString &type, const QString &id);

    Q_INVOKABLE QStringList categories() const { return m_categories; }
    void setCategories(const QStringList &categories);

    // QML accessible methods
    /**
     * @brief Récupère le modèle d'assets pour une catégorie et un type
     * @param category Catégorie (ex: "decoration")
     * @param type Type (ex: "grass")
     * @return Modèle filtré pour utilisation dans ListView, GridView, etc.
     * @note Le modèle est mis en cache automatiquement
     */
    Q_INVOKABLE AssetModel* getAssetModel(const QString &category, const QString &type);
    
    // ==================== MÉTHODES RECOMMANDÉES ====================
    // Ces méthodes retournent la structure Asset complète avec toutes les métadonnées
    
    /**
     * @brief [RECOMMANDÉ] Récupère un asset complet par son nom de fichier
     * @param category Catégorie de l'asset
     * @param type Type de l'asset
     * @param filename Nom du fichier avec extension (ex: "grass_01.png")
     * @return QVariantMap avec tous les champs de l'asset
     * @example var asset = AssetManager.getAssetByFilename("decoration", "grass", "grass_01.png");
     */
    Q_INVOKABLE QVariantMap getAssetByFilename(const QString &category, const QString &type, const QString &filename);
    
    /**
     * @brief [RECOMMANDÉ] Récupère un asset complet par son ID
     * @param category Catégorie de l'asset
     * @param type Type de l'asset
     * @param id Identifiant de l'asset (sans extension, ex: "grass_01")
     * @return QVariantMap avec tous les champs de l'asset (vide si non trouvé)
     * @note En QML, vérifiez if (asset.id) pour savoir si l'asset a été trouvé
     * @example var asset = AssetManager.getAssetById("decoration", "grass", "grass_01");
     */
    Q_INVOKABLE QVariantMap getAssetById(const QString &category, const QString &type, const QString &id);
    
    /**
     * @brief Récupère un asset aléatoire parmi ceux disponibles pour une catégorie et un type
     * @param category Catégorie de l'asset (ex: "decoration")
     * @param type Type de l'asset (ex: "grass")
     * @return QVariantMap avec tous les champs de l'asset (vide si aucun asset trouvé)
     * @note En QML, vérifiez if (asset.id) pour savoir si un asset a été trouvé
     * @example var randomAsset = AssetManager.getRandomAsset("decoration", "grass");
     */
    Q_INVOKABLE QVariantMap getRandomAsset(const QString &category, const QString &type);
    
    Q_INVOKABLE void loadAssets();
    Q_INVOKABLE void setAssetsBasePath(const QString &basePath);
    
    /**
     * @brief Liste les types disponibles pour une catégorie
     * @param category Nom de la catégorie
     * @return Liste des types (ex: ["grass", "tree", "rock"])
     */
    Q_INVOKABLE QStringList getAvailableTypes(const QString &category) const;
    
    /**
     * @brief Liste toutes les catégories disponibles
     * @return Liste des catégories (ex: ["decoration", "player_icons"])
     */
    Q_INVOKABLE QStringList getAvailableCategories() const;
    
    /**
     * @brief Vérifie si au moins un asset d'une catégorie/type a un tag ou une description contenant le texte recherché
     * @param category Catégorie de l'asset
     * @param type Type de l'asset
     * @param searchText Texte à rechercher (insensible à la casse)
     * @return true si au moins un asset matche
     */
    Q_INVOKABLE bool hasMatchingAsset(const QString &category, const QString &type, const QString &searchText);

    /**
     * @brief Vérifie si un asset existe
     * @param category Catégorie de l'asset
     * @param type Type de l'asset
     * @param id Identifiant de l'asset
     * @return true si l'asset existe, false sinon
     */
    Q_INVOKABLE bool isAssetValid(const QString &category, const QString &type, const QString &id);
    
    Q_INVOKABLE void reloadAssets();
    
    /**
     * @brief Retourne le chemin de l'image par défaut (nopic.webp)
     * @return Chemin vers l'asset de fallback dans les ressources Qt
     * @note Utilisé automatiquement quand un asset n'est pas trouvé
     */
    Q_INVOKABLE QString getDefaultAssetPath() const;

    // ==================== GÉNÉRATION DE MÉTADONNÉES ====================
    
    /**
     * @brief Génère le fichier metadata.json pour un répertoire
     * @param directoryPath Chemin du répertoire contenant les images
     * @return true si la génération a réussi
     * @note Scanne tous les fichiers .png, .jpg, .jpeg, .webp
     * @note Génère automatiquement les dimensions, ratios et extensions
     */
    Q_INVOKABLE bool generateMetadataForDirectory(const QString &directoryPath);
    
    /**
     * @brief Génère les metadata.json pour tous les répertoires d'assets
     * @return true si toutes les générations ont réussi
     */
    Q_INVOKABLE bool generateAllMetadata();
    
    /**
     * @brief Scanne et liste tous les assets disponibles
     * @return Liste descriptive des assets (ex: "decoration/grass (5 images)")
     */
    Q_INVOKABLE QStringList scanAvailableAssets();

    Q_INVOKABLE QStringList getAvailableBackgrounds() const;


    Q_INVOKABLE QStringList getAvailableModels() const;

    /**
     * @brief Liste des modèles 3D utilisables pour un PlayerProfile.
     * Source double : scan QRC `:/asset/models/` (built-in) + scan
     * `<AppData>/models/` (téléchargés). Ne retient que les dossiers contenant
     * un `<name>.qml`. Dédup par nom (priorité QRC). Inclut aussi les primitives
     * "Cube" et "Sphere" (toujours disponibles, utilisées en fallback).
     */
    Q_INVOKABLE QStringList availablePlayerModels() const;

    Q_INVOKABLE bool isTransparent(float px, float py, QString path);

    Q_INVOKABLE QString getAppDataPath() const;

    // ==================== Artefacts par hash (D16/D36, plan T4-1/M8) ==========
    // Résolution/diagnostic d'un artefact référencé par une tuile. Délègue à
    // ArtifactRegistry (store par hash). Permet à l'UI/éditeur de désactiver
    // l'élément avec un diagnostic clair quand le blob est absent (D16).

    // Vrai si le blob ET le manifeste de ce contentHash sont présents localement.
    Q_INVOKABLE bool isArtifactAvailable(const QString &contentHash) const;
    // Chemin disque absolu du blob (existe ou non) — "" si le hash est invalide.
    Q_INVOKABLE QString artifactBlobPath(const QString &contentHash) const;
    // Manifeste de l'artefact en QVariantMap (vide si inconnu).
    Q_INVOKABLE QVariantMap artifactManifest(const QString &contentHash) const;

    // ==================== Color ID Map (résolution runtime) ====================
    // Lecture des ressources Color ID Map d'un modèle installé, par nom
    // (<AppData>/models/<name>/ prioritaire, QRC :/asset/models/<name>/ en
    // fallback). Utilisé par SkinnedModel/PCP_SkinPicker (runtime/éditeur).
    // Cf. doc/architecture/COLOR_ID_MAP_INTEGRATION_PLAN.md.

    // Résout le dossier d'un modèle (AppData prioritaire, QRC fallback).
    Q_INVOKABLE QString modelDir(const QString &modelName) const;
    // model_manifest.json du modèle → QVariantMap (vide si absent).
    Q_INVOKABLE QVariantMap readModelManifest(const QString &modelName) const;
    // Sous-dossiers de <model>/skins (= skins disponibles), triés.
    Q_INVOKABLE QStringList listModelSkins(const QString &modelName) const;
    // Fichiers image de <model>/skins/<skin>/textures.
    Q_INVOKABLE QStringList listSkinTextures(const QString &modelName, const QString &skin) const;
    // Contenu de <model>/skins/<skin>/skin.json ("" si absent).
    Q_INVOKABLE QString readSkinJson(const QString &modelName, const QString &skin) const;
    // Variantes (basenames) de <model>/skins/<skin>/variants.
    Q_INVOKABLE QStringList listSkinVariants(const QString &modelName, const QString &skin) const;
    // Contenu d'une variante <model>/skins/<skin>/variants/<name>.json ("" si absent).
    Q_INVOKABLE QString loadSkinVariant(const QString &modelName, const QString &skin,
                                        const QString &variant) const;

public slots:

signals:
    void assetsBasePathChanged();
    void categoriesChanged();

private:
    void loadCategory(const QString &categoryPath, const QString &categoryName);
    void loadTypeFromDirectory(const QString &typePath, const QString &typeName, const QString &categoryName, const QHash<QString, QPair<QStringList, QString>> &tagsData);
    void cleanupInvalidModels();

    QString m_assetsBasePath;
    static AssetManager *m_pThis;
    
    QHash<QString, AssetModel*> m_models;

    // Cache d'images pour isTransparent (évite de recharger l'image à chaque appel)
    QHash<QString, QImage> m_imageCache;

    QStringList m_categories;
};

#endif // ASSET_MANAGER_H
