#ifndef ACCOUNT_MANAGER_H
#define ACCOUNT_MANAGER_H

#include <QObject>
#include <QtQml>
#include <QString>
#include <QByteArray>
#include <QDateTime>

class AccountManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString uniqueId READ uniqueId CONSTANT)
    Q_PROPERTY(QString nickname READ nickname WRITE setNickname NOTIFY nicknameChanged)
    Q_PROPERTY(bool hasAccount READ hasAccount NOTIFY hasAccountChanged)
    Q_PROPERTY(QByteArray privateKey READ privateKey NOTIFY privateKeyChanged)
    Q_PROPERTY(QString keyCreatedAt READ keyCreatedAt NOTIFY privateKeyChanged)

public:
    explicit AccountManager(QObject *parent = nullptr);
    ~AccountManager() override;

    static AccountManager* instance();

    // Getters
    QString uniqueId() const { return m_uniqueId; }
    QString nickname() const { return m_nickname; }
    bool hasAccount() const { return m_hasAccount; }
    QByteArray privateKey() const { return m_privateKey; }
    QString keyCreatedAt() const { return m_keyCreatedAt.toString(Qt::ISODate); }

    // Setters
    void setNickname(const QString &nickname);

    // Q_INVOKABLE methods for QML
    Q_INVOKABLE void createAccount(const QString &nickname);
    Q_INVOKABLE bool regenerateKeys();
    Q_INVOKABLE void loadAccount();
    Q_INVOKABLE void saveAccount();

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
    void nicknameChanged();
    void hasAccountChanged();
    void privateKeyChanged();
    void keysRegenerated();
    void accountCreated();

private:
    void generateUniqueId();
    void generateKeys();

    static AccountManager* s_instance;

    QString m_uniqueId;
    QString m_nickname;
    bool m_hasAccount = false;
    QByteArray m_privateKey;
    QDateTime m_keyCreatedAt;
};

#endif // ACCOUNT_MANAGER_H
