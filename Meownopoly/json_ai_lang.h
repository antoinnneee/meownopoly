#ifndef JSON_AI_LANG_H
#define JSON_AI_LANG_H

#include <QObject>
#include <QQmlEngine>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QList>
#include <QPair>


typedef QPair<QString, QString> PairString;
typedef QList<PairString> ListPairs;

class JSON_AI_lang : public QObject
{
    Q_OBJECT
public:
    static void registerQml();
    static JSON_AI_lang *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    ListPairs parseJson(const QString &fileName);
    void generateJson(const ListPairs& pairs, const QString& fileName) ;
public slots:

signals:

private slots:

private:
    explicit JSON_AI_lang(QObject *parent = nullptr);
    static JSON_AI_lang *m_pThis;
};

#endif // JSON_AI_LANG_H
