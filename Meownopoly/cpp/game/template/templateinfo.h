#ifndef TEMPLATEINFO_H
#define TEMPLATEINFO_H

#include <QString>
#include <QObject>
#include <QJsonObject>
#include <QJsonArray>

/**
 * @brief Classe contenant les métadonnées d'un template
 * 
 * Un template est un groupe d'éléments (SnapableElements) qui peuvent être
 * placés ensemble sur la carte. Cette classe stocke les informations
 * sur le template lui-même (nom, description, etc.) ainsi que les
 * métadonnées nécessaires pour reconstruire la disposition des éléments.
 */
class TemplateInfo : public QObject
{
    Q_OBJECT

    // Propriétés de base du template
    Q_PROPERTY(QString templateName READ templateName WRITE setTemplateName NOTIFY templateNameChanged)
    Q_PROPERTY(QString templateDescription READ templateDescription WRITE setTemplateDescription NOTIFY templateDescriptionChanged)
    Q_PROPERTY(QString templateCreationDate READ templateCreationDate WRITE setTemplateCreationDate NOTIFY templateCreationDateChanged)
    Q_PROPERTY(QString templateAuthor READ templateAuthor WRITE setTemplateAuthor NOTIFY templateAuthorChanged)
    Q_PROPERTY(int version READ version WRITE setVersion NOTIFY versionChanged)
    
    // Propriétés de la bounding box (zone englobante du template)
    Q_PROPERTY(int boundingBoxWidth READ boundingBoxWidth WRITE setBoundingBoxWidth NOTIFY boundingBoxWidthChanged)
    Q_PROPERTY(int boundingBoxHeight READ boundingBoxHeight WRITE setBoundingBoxHeight NOTIFY boundingBoxHeightChanged)
    
    // Propriétés pour l'origine (point de référence pour le placement)
    Q_PROPERTY(int originOffsetX READ originOffsetX WRITE setOriginOffsetX NOTIFY originOffsetXChanged)
    Q_PROPERTY(int originOffsetY READ originOffsetY WRITE setOriginOffsetY NOTIFY originOffsetYChanged)
    
    // Nombre d'éléments dans le template
    Q_PROPERTY(int elementCount READ elementCount WRITE setElementCount NOTIFY elementCountChanged)
    
    // Chemin vers l'aperçu/thumbnail du template (optionnel)
    Q_PROPERTY(QString thumbnailPath READ thumbnailPath WRITE setThumbnailPath NOTIFY thumbnailPathChanged)
    
    // Indique si c'est un template par défaut (non modifiable/supprimable)
    Q_PROPERTY(bool isDefault READ isDefault WRITE setIsDefault NOTIFY isDefaultChanged)

public:
    explicit TemplateInfo(QObject *parent = nullptr);
    explicit TemplateInfo(const QJsonObject &json, QObject *parent = nullptr);
    
    static void registerQml();
    
    // Sérialisation
    QJsonObject toJsonObject() const;
    QString toJSON() const;
    
    // Getters
    QString templateName() const;
    QString templateDescription() const;
    QString templateCreationDate() const;
    QString templateAuthor() const;
    int version() const;
    int boundingBoxWidth() const;
    int boundingBoxHeight() const;
    int originOffsetX() const;
    int originOffsetY() const;
    int elementCount() const;
    QString thumbnailPath() const;
    bool isDefault() const;
    
    // Setters
    void setTemplateName(const QString &name);
    void setTemplateDescription(const QString &description);
    void setTemplateCreationDate(const QString &date);
    void setTemplateAuthor(const QString &author);
    void setVersion(int version);
    void setBoundingBoxWidth(int width);
    void setBoundingBoxHeight(int height);
    void setOriginOffsetX(int offsetX);
    void setOriginOffsetY(int offsetY);
    void setElementCount(int count);
    void setThumbnailPath(const QString &path);
    void setIsDefault(bool isDefault);

signals:
    void templateNameChanged();
    void templateDescriptionChanged();
    void templateCreationDateChanged();
    void templateAuthorChanged();
    void versionChanged();
    void boundingBoxWidthChanged();
    void boundingBoxHeightChanged();
    void originOffsetXChanged();
    void originOffsetYChanged();
    void elementCountChanged();
    void thumbnailPathChanged();
    void isDefaultChanged();

private:
    QString m_templateName;
    QString m_templateDescription;
    QString m_templateCreationDate;
    QString m_templateAuthor;
    int m_version = 1;
    int m_boundingBoxWidth = 0;
    int m_boundingBoxHeight = 0;
    int m_originOffsetX = 0;
    int m_originOffsetY = 0;
    int m_elementCount = 0;
    QString m_thumbnailPath;
    bool m_isDefault = false;
};

#endif // TEMPLATEINFO_H

