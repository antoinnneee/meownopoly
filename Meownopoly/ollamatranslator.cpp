#include "ollamatranslator.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QFile>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonParseError>
#include <QDebug>

OllamaTranslator *OllamaTranslator::m_pThis = nullptr;

OllamaTranslator::OllamaTranslator(const QString &modelName,
                                   const QUrl &ollamaUrl,
                                   QObject *parent)
    : QObject(parent)
    , m_ollamaUrl(ollamaUrl)
    , m_modelName(modelName)
{
    // Rien de particulier dans le constructeur
}

void OllamaTranslator::registerQml()
{
    qmlRegisterSingletonType<OllamaTranslator>("OllamaTranslator",
                                               1,
                                               0,
                                               "OllamaTranslator",
                                               &OllamaTranslator::qmlInstance);
}

OllamaTranslator *OllamaTranslator::instance()
{
    if (m_pThis == nullptr) // avoid creation of new instances
    {
        m_pThis = new OllamaTranslator;
    }
    return m_pThis;
}

QObject *OllamaTranslator::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);
    // C++ and QML instance they are the same instance
    return OllamaTranslator::instance();
}

bool OllamaTranslator::sendTranslationRequest(const QJsonArray &jsonArray, const QString &targetLang)
{
    if (!m_ollamaUrl.isValid()) {
        emit errorOccurred(tr("URL invalide pour Ollama : %1").arg(m_ollamaUrl.toString()));
        return false;
    }

    // Convertit le QJsonArray en texte brut pour l’inclure dans le prompt
    QJsonDocument doc(jsonArray);
    QString jsonString = QString::fromUtf8(doc.toJson(QJsonDocument::Compact));

    /*!
     * Prompt simpliste :
     * On demande au modèle de traduire chaque champ "text" de l'objet JSON ci-dessous en targetLang
     * et de renvoyer un JSON de même structure.
     *
     * En pratique, vous pouvez personnaliser beaucoup plus finement
     * (messages de contexte, role system, etc. via /api/chat)
     * ou ajouter un schema si vous voulez être sûr de recevoir du JSON structuré.
     */
    QString prompt = QString(
                         "traduit en %1 uniquement les champs nommés \"text\", répond uniquement avec le tableau json sans rien ajouter d'autre : %2 \n\n format de réponse : [{JSON_TRADUIT}, ...]")
                         .arg(targetLang, jsonString);

    // Prépare la requête vers /api/generate
    QUrl endpoint = m_ollamaUrl.resolved(QUrl("/api/generate"));
    QNetworkRequest request(endpoint);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    // Corps de la requête : {"model": "...", "prompt": "...", "stream": false, ...}
    QJsonObject requestBody;
    requestBody["model"]  = m_modelName;
    requestBody["prompt"] = prompt;
    requestBody["stream"] = false;  // on veut une seule réponse finale
    requestBody["temperature"] = 1.5;

    // Vous pouvez régler d'autres paramètres (e.g. "options": {...}) si nécessaire
    // Par exemple la temperature, top_p, etc.

    QJsonDocument requestDoc(requestBody);
    QByteArray requestData = requestDoc.toJson(QJsonDocument::Compact);

    // Envoie de la requête
    qDebug().noquote() << "ready to send : " << requestBody;
    QNetworkReply *reply = m_networkManager.post(request, requestData);
    if (!reply) {
        emit errorOccurred(tr("Impossible d'envoyer la requête réseau à Ollama."));
        return false;
    }

    // Connexion du slot de fin de requête
    connect(reply, &QNetworkReply::finished, this, &OllamaTranslator::onTranslationReplyFinished);

    return true;
}

bool OllamaTranslator::sendTranslationRequestFromFile(const QString &filePath, const QString &targetLang)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit errorOccurred(tr("Impossible d'ouvrir le fichier : %1").arg(filePath));
        return false;
    }

    QByteArray data = file.readAll();
    file.close();

    // Parsing JSON
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        emit errorOccurred(tr("Erreur de parsing JSON : %1").arg(parseError.errorString()));
        return false;
    }

    if (!doc.isArray()) {
        emit errorOccurred(tr("Le fichier JSON ne contient pas un tableau à la racine."));
        return false;
    }

    QJsonArray jsonArray = doc.array();
    return sendTranslationRequest(jsonArray, targetLang);
}

void OllamaTranslator::onTranslationReplyFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply) {
        // Cas anormal
        emit errorOccurred(tr("Réponse réseau invalide (pas de QNetworkReply)."));
        return;
    }

    reply->deleteLater();

    // Vérification d’erreur réseau
    if (reply->error() != QNetworkReply::NoError) {
        emit errorOccurred(tr("Erreur réseau (%1) : %2")
                               .arg(reply->error())
                               .arg(reply->errorString()));
        return;
    }

    // Lecture de la réponse brute
    QByteArray rawData = reply->readAll();

    // Tentative de parsing JSON
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(rawData, &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        emit errorOccurred(tr("Impossible de parser la réponse d'Ollama : %1")
                               .arg(parseError.errorString()));
        return;
    }

    // Format de réponse attendu (selon la doc /api/generate):
    // {
    //   "model": "...",
    //   "created_at": "...",
    //   "response": "LE TEXTE GÉNÉRÉ PAR LE MODÈLE (qui doit être du JSON)",
    //   "done": true,
    //   ...
    // }
    QJsonObject rootObj = doc.object();
    if (!rootObj.contains("response")) {
        emit errorOccurred(tr("La réponse Ollama ne contient pas le champ 'response'."));
        return;
    }

    QString responseString = rootObj.value("response").toString().trimmed();

    QRegularExpression regex("<think>.*?</think>\\n?",
                             QRegularExpression::DotMatchesEverythingOption);
    QString cleanText = responseString.remove(regex);



    // On suppose ici que le modèle a bien renvoyé du JSON. On retente un parse JSON
    // sur ce champ "response".
    QJsonParseError parseError2;
    QJsonDocument docTranslated = QJsonDocument::fromJson(cleanText.toUtf8(), &parseError2);
    if (parseError2.error != QJsonParseError::NoError) {
        // Le modèle a peut-être renvoyé du texte non-JSON ou un JSON non valide.
        // Dans un usage réaliste, on peut tenter de post-traiter ou d’informer l’utilisateur.
        emit errorOccurred(tr("Le champ 'response' reçu n'est pas un JSON valide : %1.\n"
                              "Contenu reçu : %2")
                               .arg(parseError2.errorString())
                               .arg(responseString));
        return;
    }

    if (!docTranslated.isArray()) {
        emit errorOccurred(tr("Le 'response' JSON retourné n'est pas un tableau JSON."));
        return;
    }

    QJsonArray translatedArray = docTranslated.array();
    emit translationCompleted(translatedArray);
}
