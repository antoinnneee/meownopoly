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

#define DEFAULT_ASSETS_LOCATION "asset_extracted/"

class AssetModel : public QAbstractListModel
{
    Q_OBJECT

private:
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
    };

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
        FilenameRole
    };

    explicit AssetModel(QObject *parent = nullptr);

    // QAbstractListModel interface
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Asset management
    void addAsset(const QString &path, const QString &type, const QString &category,
                  int ratioWidth, int ratioHeight, int width, int height, const QString &id, const QString &filename);
    void clear();
    
    // Filtering
    Q_INVOKABLE AssetModel* createFilteredModel(const QString &type) const;

    QList<Asset> getAssetList(){return m_assets;}

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
    Q_INVOKABLE QString buildAssetPath(const QString &category, const QString &type, const QString &filename) const;
    Q_INVOKABLE QString getAssetPath(const QString &category, const QString &type, const QString &id);

    Q_INVOKABLE QString getAssetElement(const QString &category, const QString &type, const QString &id, const QString &elementName);
    Q_INVOKABLE QString getAnimatedGifPath(const QString &category, const QString &type, const QString &id);

    Q_INVOKABLE QStringList categories() const { return m_categories; }
    void setCategories(const QStringList &categories);

    // QML accessible methods
    Q_INVOKABLE AssetModel* getAssetModel(const QString &category, const QString &type);

    Q_INVOKABLE void loadAssets();
    Q_INVOKABLE void setAssetsBasePath(const QString &basePath);
    Q_INVOKABLE QStringList getAvailableTypes(const QString &category) const;
    Q_INVOKABLE QStringList getAvailableCategories() const;
    Q_INVOKABLE bool isAssetValid(const QString &category, const QString &type, const QString &id);
    Q_INVOKABLE void reloadAssets();

    // Metadata generation
    Q_INVOKABLE bool generateMetadataForDirectory(const QString &directoryPath);
    Q_INVOKABLE bool generateAllMetadata();
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
