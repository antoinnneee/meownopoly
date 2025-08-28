#ifndef DECORATIONPARAMETER_H
#define DECORATIONPARAMETER_H

#include <QObject>

class DecorationParameter : public QObject
{
    Q_OBJECT
public:
    explicit DecorationParameter(QObject *parent = nullptr);
    explicit DecorationParameter(const QJsonObject &json, QObject *parent = nullptr);
    QString toJSON();
    
    Q_PROPERTY(QString decorationType READ decorationType WRITE setDecorationType NOTIFY decorationTypeChanged)
    Q_PROPERTY(QString decorationId READ decorationId WRITE setDecorationId NOTIFY decorationIdChanged)

    QString decorationType() const;
    void setDecorationType(const QString &decorationType);
    QString decorationId() const;
    void setDecorationId(const QString &decorationId);

signals:
    void decorationTypeChanged();
    void decorationIdChanged();

private:
    QString m_decorationType;
    QString m_decorationId;
};

#endif // DECORATIONPARAMETER_H
