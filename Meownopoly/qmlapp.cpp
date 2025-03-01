#include <QDebug>

#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QtQml/QQmlContext>

#include "qmlapp.h"

#include <QDir>
#include <QStandardPaths>
#include <ollamatranslator.h>
#include "game.h"

#include <QJsonArray>
#include <QJsonObject>
#ifdef Q_OS_ANDROID
#include <QJniObject.h>
#endif

QmlApp::QmlApp(QWindow *parent)
    : QQmlApplicationEngine(parent)
{
    QQuickStyle::setStyle("Material");
    Game::registerQml();
    OllamaTranslator::registerQml();


    load(QUrl("qrc:/qml/main.qml"));
    game = Game::instance();
    ollama = OllamaTranslator::instance();


    QObject::connect(ollama, &OllamaTranslator::errorOccurred,
                     [&](const QString &err) {
                         qWarning() << "Erreur:" << err;
                         //                         app.quit();
                     });

    // Connexion des signaux
    QObject::connect(ollama, &OllamaTranslator::translationCompleted,
                     [&](const QJsonArray &translatedJson) {
                         qDebug() << "Traduction terminée !";
                         QJsonDocument doc(translatedJson);
                         qDebug().noquote() << doc.toJson(QJsonDocument::Indented);
                         // Ici vous pouvez sauvegarder dans un fichier si nécessaire
//                         app.quit();
                     });

    QJsonArray arr;
    arr.append(QJsonObject{{"id", "valider"}, {"text", "Valider"}});
    arr.append(QJsonObject{{"id", "annuler"}, {"text", "Annuler"}});
    arr.append(QJsonObject{{"id", "titre"},   {"text", "Le petit bonhomme"}});
    arr.append(QJsonObject{{"id", "story"},   {"text", "NE CROISEZ PAS LES EFFLUVENTS"}});
    ollama->sendTranslationRequest(arr, "verlen  "
                                        "");  // Traduire en anglais

    game->init();
}

/*
 * Gestion Close Event
 */
bool QmlApp::event(QEvent *event)
{
    if (event->type() == QEvent::Close) {
        // return true to cancel close event
    }
    return QQmlApplicationEngine::event(event);
}

QmlApp::~QmlApp() {


}
