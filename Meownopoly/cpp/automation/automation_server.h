#ifndef AUTOMATION_SERVER_H
#define AUTOMATION_SERVER_H

#include <QObject>
#include <QHash>
#include <QJsonObject>
#include <QJsonValue>
#include <QPointer>

class QWebSocketServer;
class QWebSocket;
class QQuickWindow;
class QQuickItem;
class QObject;

/**
 * AutomationServer — serveur d'automation/test embarqué dans l'app.
 *
 * Canal de debug LOCAL uniquement : écoute sur 127.0.0.1, opt-in via
 * l'argument CLI `--automation-port <N>` ou la variable d'env
 * `MEOW_AUTOMATION_PORT`. Quand aucun port n'est fourni, le serveur n'est
 * jamais instancié (cf. AutomationServer::maybeCreate).
 *
 * Protocole : messages JSON texte requête/réponse.
 *   Requête  : { "id": <any>, "cmd": "<nom>", "params": { ... } }
 *   Réponse  : { "id": <any>, "ok": true, "result": <any> }
 *           ou { "id": <any>, "ok": false, "error": "<message>" }
 *
 * Tout tourne sur le GUI thread (le QWebSocket vit sur le main thread), car
 * les commandes manipulent la scène QML qui appartient au GUI thread. Aucun
 * thread dédié n'est créé.
 */
class AutomationServer : public QObject
{
    Q_OBJECT

public:
    explicit AutomationServer(quint16 port, QObject *parent = nullptr);
    ~AutomationServer() override;

    /// Port effectivement écouté (0 si l'écoute a échoué).
    quint16 port() const { return m_port; }
    bool isListening() const;

    /**
     * Résout le port d'automation depuis les arguments CLI et l'environnement.
     * Priorité : `--automation-port <N>` > `MEOW_AUTOMATION_PORT`.
     * Retourne 0 si aucun port n'est demandé (→ pas de serveur).
     */
    static quint16 resolvePort(const QStringList &args);

    /**
     * Crée le serveur si un port est demandé, sinon retourne nullptr.
     * `parent` prend ownership de l'instance créée.
     */
    static AutomationServer *maybeCreate(const QStringList &args, QObject *parent);

private slots:
    void onNewConnection();
    void onTextMessageReceived(const QString &message);
    void onSocketDisconnected();

private:
    // — Dispatch des commandes —
    QJsonValue dispatch(const QString &cmd, const QJsonObject &params, bool &ok,
                        QString &error, QWebSocket *client, const QJsonValue &id,
                        bool &deferred);

    // Commandes synchrones
    QJsonValue cmdPing(const QJsonObject &params, bool &ok, QString &error);
    QJsonValue cmdTree(const QJsonObject &params, bool &ok, QString &error);
    QJsonValue cmdFind(const QJsonObject &params, bool &ok, QString &error);
    QJsonValue cmdGet(const QJsonObject &params, bool &ok, QString &error);
    QJsonValue cmdSet(const QJsonObject &params, bool &ok, QString &error);
    QJsonValue cmdInvoke(const QJsonObject &params, bool &ok, QString &error);
    QJsonValue cmdMouse(const QString &cmd, const QJsonObject &params, bool &ok, QString &error);
    QJsonValue cmdWheel(const QJsonObject &params, bool &ok, QString &error);
    QJsonValue cmdKeys(const QJsonObject &params, bool &ok, QString &error);
    QJsonValue cmdScreenshot(const QJsonObject &params, bool &ok, QString &error);
    QJsonValue cmdQuit(const QJsonObject &params, bool &ok, QString &error);

    // Commande différée (réponse asynchrone)
    void cmdWaitFor(const QJsonObject &params, QWebSocket *client, const QJsonValue &id);

    // — Helpers —
    /// Fenêtre QQuickWindow principale (première top-level visible).
    QQuickWindow *primaryWindow() const;
    /// Toutes les fenêtres QQuickWindow top-level.
    QList<QQuickWindow *> quickWindows() const;

    /// Résout un objet cible depuis params (objectName, ou id pointeur "0x...").
    QObject *resolveTarget(const QJsonObject &params, QString &error) const;
    /// Recherche récursive par objectName (+ className optionnel) dans une racine.
    void findRecursive(QObject *root, const QString &objectName, const QString &className,
                       QList<QObject *> &out) const;

    /// Encode un pointeur QObject en id stable ("0x...").
    static QString encodeId(const QObject *obj);
    /// Décode un id ("0x...") en pointeur, validé contre les objets connus.
    QObject *decodeId(const QString &id) const;

    /// Sérialise un objet QML en JSON (objectName, className, geometry, etc.).
    QJsonObject objectToJson(QObject *obj, int depth, int maxDepth,
                             const QString &filter) const;
    /// Géométrie en coords fenêtre pour un QQuickItem (x/y/width/height + scène).
    QJsonObject itemGeometry(QQuickItem *item) const;

    /// Envoie une réponse de succès/erreur à un client.
    void sendResponse(QWebSocket *client, const QJsonValue &id, bool ok,
                      const QJsonValue &resultOrError);

    /// Convertit QVariant ↔ QJsonValue (best-effort).
    static QJsonValue variantToJson(const QVariant &v);
    static QVariant jsonToVariant(const QJsonValue &v);

    QWebSocketServer *m_server = nullptr;
    QList<QWebSocket *> m_clients;
    quint16 m_port = 0;
};

#endif // AUTOMATION_SERVER_H
