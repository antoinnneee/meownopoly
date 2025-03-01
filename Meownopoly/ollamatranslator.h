#ifndef OLLAMATRANSLATOR_H
#define OLLAMATRANSLATOR_H

#include <QObject>
#include <QQmlEngine>
#include <QFile>
#include <QJsonDocument>
#include <QNetworkRequest>
#include <qnetworkaccessmanager.h>
#include <QJsonParseError>
#include <QDebug>

class OllamaTranslator : public QObject
{
    Q_OBJECT
public:
    static void registerQml();
    static OllamaTranslator *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    /*!
     * \brief Envoie pour traduction un fichier JSON local (ou un QJsonArray déjà chargé)
     * \param jsonArray   Le tableau JSON contenant des objets { "id": "...", "text": "..." }
     * \param targetLang  Langue cible, par exemple "en", "de", "es", "fr", etc.
     * \return            \c true si la requête a pu être envoyée, \c false sinon.
     *
     * Le résultat de la traduction sera émis via le signal translationCompleted(...)
     */
    bool sendTranslationRequest(const QJsonArray &jsonArray, const QString &targetLang);

    /*!
     * \brief Lit un fichier JSON local puis envoie la traduction.
     * \param filePath    Chemin du fichier JSON
     * \param targetLang  Langue cible
     */
    bool sendTranslationRequestFromFile(const QString &filePath, const QString &targetLang);


public slots:

signals:
    /*!
     * \brief Émis quand la traduction est terminée (succès).
     * \param translatedJson  Le tableau JSON renvoyé par Ollama après traduction
     */
    void translationCompleted(const QJsonArray &translatedJson);

    /*!
     * \brief Émis en cas d'erreur réseau ou de parsing.
     * \param errorString  Description de l'erreur
     */
    void errorOccurred(const QString &errorString);

private slots:
    void onTranslationReplyFinished();

private:
    explicit OllamaTranslator(const QString &modelName = "deepseek-r1:7b",
                              const QUrl &ollamaUrl = QUrl("http://localhost:11434"),
                              QObject *parent = nullptr);
    static OllamaTranslator *m_pThis;

    QNetworkAccessManager m_networkManager;
    QUrl                  m_ollamaUrl;
    QString               m_modelName;
};

#endif // OLLAMATRANSLATOR_H
