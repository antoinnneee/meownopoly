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

class AssetModel : public QAbstractListModel
{
    Q_OBJECT

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
};

class AssetManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(AssetModel* decorationModel READ decorationModel NOTIFY decorationModelChanged)
    Q_PROPERTY(AssetModel* playerIconModel READ playerIconModel NOTIFY playerIconModelChanged)
    Q_PROPERTY(AssetModel* tileModel READ tileModel NOTIFY tileModelChanged)
    Q_PROPERTY(QString assetsBasePath READ assetsBasePath NOTIFY assetsBasePathChanged)

public:
    explicit AssetManager(QObject *parent = nullptr);
    static void registerQml();
    static AssetManager* instance();
    static QObject* qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    // Property getters
    AssetModel* decorationModel() const { return m_decorationModel; }
    AssetModel* playerIconModel() const { return m_playerIconModel; }
    AssetModel* tileModel() const { return m_tileModel; }
    QString assetsBasePath() const { return m_assetsBasePath; }
    Q_INVOKABLE QString buildAssetPath(const QString &category, const QString &type, const QString &filename) const;

    // QML accessible methods
    Q_INVOKABLE AssetModel* getTypeModel(const QString &category, const QString &type);
    Q_INVOKABLE QString getDecorationPath(const QString &type, const QString &id) const;
    Q_INVOKABLE QString getPlayerIconPath(const QString &id) const;
    Q_INVOKABLE QString getTilePath(const QString &type, const QString &id) const;

    Q_INVOKABLE void loadAssets();
    Q_INVOKABLE void setAssetsBasePath(const QString &basePath);
    Q_INVOKABLE QStringList getAvailableTypes(const QString &category) const;
    Q_INVOKABLE QStringList getAvailableCategories() const;
    
    // Metadata generation
    Q_INVOKABLE bool generateMetadataForDirectory(const QString &directoryPath);
    Q_INVOKABLE bool generateAllMetadata();
    Q_INVOKABLE QStringList scanAvailableAssets() const;

public slots:

signals:
    void decorationModelChanged();
    void playerIconModelChanged();
    void assetsBasePathChanged();
    void tileModelChanged();
private:
    void loadCategory(const QString &categoryPath, const QString &categoryName);
    void loadTypeFromDirectory(const QString &typePath, const QString &typeName, const QString &categoryName);

    AssetModel *m_decorationModel;
    AssetModel *m_playerIconModel;
    AssetModel *m_tileModel;
    QString m_assetsBasePath;
    static AssetManager *m_pThis;
    
    // Cache for filtered models
    mutable QHash<QString, AssetModel*> m_filteredModels;
};

#endif // ASSET_MANAGER_H
