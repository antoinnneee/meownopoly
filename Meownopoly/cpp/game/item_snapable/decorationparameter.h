#ifndef DECORATIONPARAMETER_H
#define DECORATIONPARAMETER_H

#include <QObject>

class DecorationParameter : public QObject
{
    Q_OBJECT
public:

    // bool operator==(const DecorationParameter &other) const;

    explicit DecorationParameter(QObject *parent = nullptr);
    explicit DecorationParameter(const QJsonObject &json, QObject *parent = nullptr);


    QString toJSON();
    
    Q_PROPERTY(QString decorationCategory READ decorationCategory WRITE setDecorationCategory NOTIFY decorationCategoryChanged)
    Q_PROPERTY(QString decorationType READ decorationType WRITE setDecorationType NOTIFY decorationTypeChanged)
    Q_PROPERTY(QString decorationId READ decorationId WRITE setDecorationId NOTIFY decorationIdChanged)

    QString decorationCategory() const;
    void setDecorationCategory(const QString &decorationCategory);
    QString decorationType() const;
    void setDecorationType(const QString &decorationType);
    QString decorationId() const;
    void setDecorationId(const QString &decorationId);
    Q_INVOKABLE QString getAnimePath(QString imagePath);

    bool operator==(const DecorationParameter &other) const {
        return m_decorationCategory == other.m_decorationCategory
            && m_decorationType     == other.m_decorationType
            && m_decorationId       == other.m_decorationId;
    }


signals:
    void decorationTypeChanged();
    void decorationIdChanged();
    void decorationCategoryChanged();

private:
    QString m_decorationCategory;
    QString m_decorationType;
    QString m_decorationId;
};

#endif // DECORATIONPARAMETER_H
