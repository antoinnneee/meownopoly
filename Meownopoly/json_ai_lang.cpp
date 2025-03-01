#include "json_ai_lang.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QString>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QList>
#include <QPair>


ListPairs JSON_AI_lang::parseJson(const QString& fileName) {
    ListPairs result;
    QFile file(fileName);

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return result; // retourne une liste vide en cas d'erreur
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc(QJsonDocument::fromJson(data));

    if (doc.isArray()) {
        const QJsonArray& array = doc.array();

        for (const QJsonValue& val : array) {
            const QJsonObject& obj = val.toObject();

            QString id = obj.value("id").toString();
            QString text = obj.value("text").toString();

            if (!id.isEmpty() && !text.isEmpty()) { // on ignore les entrées incomplètes
                result.append(QPair<QString, QString>(id, text));
            }
        }
    }

    return result;
}

void JSON_AI_lang::generateJson(const ListPairs& pairs, const QString& fileName) {
    QJsonArray array;

    for (const PairString& pair : pairs) {
        QJsonObject obj;
        obj["id"] = pair.first;
        obj["text"] = pair.second;
        array.append(obj);
    }

    QJsonDocument doc(array);
    QFile file(fileName);

    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return; // ne peut pas écrire le fichier
    }

    file.write(doc.toJson());
    file.close();
}

JSON_AI_lang *JSON_AI_lang::m_pThis = nullptr;

JSON_AI_lang::JSON_AI_lang(QObject *parent)
    : QObject(parent)
{}

void JSON_AI_lang::registerQml()
{
    qmlRegisterSingletonType<JSON_AI_lang>("JSON_AI_lang",
                                           1,
                                           0,
                                           "JSON_AI_lang",
                                           &JSON_AI_lang::qmlInstance);
}

JSON_AI_lang *JSON_AI_lang::instance()
{
    if (m_pThis == nullptr) // avoid creation of new instances
    {
        m_pThis = new JSON_AI_lang;
    }
    return m_pThis;
}

QObject *JSON_AI_lang::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);
    // C++ and QML instance they are the same instance
    return JSON_AI_lang::instance();
}
