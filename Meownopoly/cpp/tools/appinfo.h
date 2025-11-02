#ifndef APPINFO_H
#define APPINFO_H

#include <QObject>
#include <QQmlEngine>

class AppInfo : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
public:
    static void registerQml();
    static AppInfo *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    QString name() const;
    void setName(const QString &newName);

public slots:
    Q_INVOKABLE QString getVersionName();
    Q_INVOKABLE QString getVersionNumber();

signals:
    void nameChanged();

private slots:

private:
    explicit AppInfo(QObject *parent = nullptr);
    static AppInfo *m_pThis;

    QString m_name;
};

#endif // APPINFO_H
