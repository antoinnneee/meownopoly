#ifndef ACCOUNT_MANAGER_H
#define ACCOUNT_MANAGER_H

#include <QObject>
#include <QtQml>
#include <QString>

class AccountManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString uniqueId READ uniqueId NOTIFY uniqueIdChanged)
    Q_PROPERTY(QString nickname READ nickname WRITE setNickname NOTIFY nicknameChanged)
    Q_PROPERTY(QString stunServer READ stunServer WRITE setStunServerURL NOTIFY stunServerChanged)
    Q_PROPERTY(quint16 stunPort READ stunPort WRITE setStunPort NOTIFY stunPortChanged)
    Q_PROPERTY(bool hasAccount READ hasAccount NOTIFY hasAccountChanged)

public:
    explicit AccountManager(QObject *parent = nullptr);
    ~AccountManager() override;

    static AccountManager* instance();

    QString uniqueId() const { return m_uniqueId; }
    QString nickname() const { return m_nickname; }
    bool hasAccount() const { return m_hasAccount; }

    void setNickname(const QString &nickname);

    QString stunServer() const { return m_stunServer; }
    quint16 stunPort() const { return m_stunPort; }

    Q_INVOKABLE void setStunServerURL(const QString &server);
    Q_INVOKABLE void setStunPort(quint16 port);

    Q_INVOKABLE void createAccount(const QString &nickname);
    Q_INVOKABLE bool regenerateUniqueId();
    Q_INVOKABLE void loadAccount();
    Q_INVOKABLE void saveAccount();

    static QString getNewUniqueId();

    // Static registration for QML
    static void registerQml() {
        qmlRegisterSingletonType<AccountManager>("Meownopoly.Account", 1, 0, "AccountManager",
                                                 [](QQmlEngine *engine, QJSEngine *scriptEngine) -> QObject* {
                                                     Q_UNUSED(engine)
                                                     Q_UNUSED(scriptEngine)
                                                     return AccountManager::instance();
                                                 });
    }

signals:
    void uniqueIdChanged();
    void nicknameChanged();
    void stunServerChanged();
    void stunPortChanged();
    void hasAccountChanged();
    void accountCreated();

private:
    void generateUniqueId();

    static AccountManager* s_instance;

    QString m_nickname;

    QString m_uniqueId;
    QString m_stunServer = "pattouncorp.ovh";
    quint16 m_stunPort = 3000;

    bool m_hasAccount = false;
};

#endif // ACCOUNT_MANAGER_H
