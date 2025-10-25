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
        FrameCountRole
    };

    explicit AssetModel(QObject *parent = nullptr);

    // QAbstractListModel interface
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Asset management
    void addAsset(const QString &path, const QString &type, const QString &category,
                  int ratioWidth, int ratioHeight, int width, int height, const QString &id, const QString &filename, 
                  const QString &extension = "png", bool animated = false, int frameCount = 1);
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
     * @brief Vérifie si un asset existe
     * @param category Catégorie de l'asset
     * @param type Type de l'asset
     * @param id Identifiant de l'asset
     * @return true si l'asset existe, false sinon
     */
    Q_INVOKABLE bool isAssetValid(const QString &category, const QString &type, const QString &id);
    
    Q_INVOKABLE void reloadAssets();

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


    Q_INVOKABLE bool isTransparent(float px, float py, QString path);


public slots:

signals:
    void assetsBasePathChanged();
    void categoriesChanged();

private:
    void loadCategory(const QString &categoryPath, const QString &categoryName);
    void loadTypeFromDirectory(const QString &typePath, const QString &typeName, const QString &categoryName);
    void cleanupInvalidModels();

    QString m_assetsBasePath;
    static AssetManager *m_pThis;
    
    QList<QPair<QString, AssetModel*>> m_models;

    QStringList m_categories;
};

#endif // ASSET_MANAGER_H
