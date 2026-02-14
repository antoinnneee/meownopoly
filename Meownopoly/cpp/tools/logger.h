#ifndef LOGGER_H
#define LOGGER_H

#include <QObject>
#include <QQmlEngine>
#include <QString>

// Définitions pour contrôler les niveaux de log
#ifndef LOG_LEVEL_INFO
#define LOG_LEVEL_INFO 1
#endif

#ifndef LOG_LEVEL_DEBUG
#define LOG_LEVEL_DEBUG 1
#endif

#ifndef LOG_LEVEL_WARN
#define LOG_LEVEL_WARN 1
#endif

#ifndef LOG_LEVEL_ERROR
#define LOG_LEVEL_ERROR 1
#endif

#ifndef LOG_LEVEL_SUCCESS
#define LOG_LEVEL_SUCCESS 1
#endif

class Logger : public QObject
{
    Q_OBJECT
public:
    static void registerQml();
    static Logger *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

public slots:
    // Méthodes de logging avec catégorie optionnelle
    Q_INVOKABLE void log(const QString &message);
    Q_INVOKABLE void info(const QString &message, const QString &category = QString());
    Q_INVOKABLE void debug(const QString &message, const QString &category = QString());
    Q_INVOKABLE void warn(const QString &message, const QString &category = QString());
    Q_INVOKABLE void error(const QString &message, const QString &category = QString());
    Q_INVOKABLE void success(const QString &message, const QString &category = QString());


signals:

private slots:

private:
    explicit Logger(QObject *parent = nullptr);
    static Logger *m_pThis;
    
    // Méthode privée pour formater et afficher les messages
    void logMessage(const QString &level, const QString &message, const QString &category, const QString &color);
};

#endif // LOGGER_H
