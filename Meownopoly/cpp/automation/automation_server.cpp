#include "automation_server.h"

#include <QWebSocketServer>
#include <QWebSocket>
#include <QHostAddress>
#include <QGuiApplication>
#include <QQuickWindow>
#include <QQuickItem>
#include <QJsonDocument>
#include <QJsonArray>
#include <QMetaObject>
#include <QMetaMethod>
#include <QMetaProperty>
#include <QVariant>
#include <QJSValue>
#include <QJSEngine>
#include <QQmlEngine>
#include <QPointF>
#include <QPointer>
#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>
#include <QDateTime>
#include <QTimer>
#include <QImage>
#include <QMouseEvent>
#include <QWheelEvent>
#include <QKeyEvent>
#include <QCoreApplication>
#include <QDebug>
#include <QRegularExpression>
#include <functional>

// ============================================================================
// Construction / cycle de vie
// ============================================================================

AutomationServer::AutomationServer(quint16 port, QObject *parent)
    : QObject(parent)
{
    m_server = new QWebSocketServer(QStringLiteral("Meownopoly Automation"),
                                    QWebSocketServer::NonSecureMode, this);

    // SÉCURITÉ : écoute STRICTEMENT sur la loopback (127.0.0.1). Jamais
    // 0.0.0.0 — c'est un canal de debug local qui expose l'introspection
    // complète de la scène QML et la synthèse d'événements.
    if (m_server->listen(QHostAddress::LocalHost, port)) {
        m_port = m_server->serverPort();
        connect(m_server, &QWebSocketServer::newConnection,
                this, &AutomationServer::onNewConnection);
        qInfo() << "[Automation] Serveur d'automation à l'écoute sur 127.0.0.1:" << m_port;
    } else {
        qWarning() << "[Automation] Échec de l'écoute sur le port" << port
                   << ":" << m_server->errorString();
    }
}

AutomationServer::~AutomationServer()
{
    if (m_server)
        m_server->close();
    qDeleteAll(m_clients);
    m_clients.clear();
}

bool AutomationServer::isListening() const
{
    return m_server && m_server->isListening();
}

// ============================================================================
// Résolution du port (CLI / env) et fabrique conditionnelle
// ============================================================================

quint16 AutomationServer::resolvePort(const QStringList &args)
{
    // Priorité au flag CLI explicite.
    const int idx = args.indexOf(QStringLiteral("--automation-port"));
    if (idx != -1 && idx + 1 < args.size()) {
        bool conv = false;
        const uint v = args.at(idx + 1).toUInt(&conv);
        if (conv && v > 0 && v <= 65535)
            return static_cast<quint16>(v);
        qWarning() << "[Automation] --automation-port avec valeur invalide :"
                   << args.value(idx + 1);
    }

    // Sinon, variable d'environnement.
    const QByteArray env = qgetenv("MEOW_AUTOMATION_PORT");
    if (!env.isEmpty()) {
        bool conv = false;
        const uint v = QString::fromUtf8(env).toUInt(&conv);
        if (conv && v > 0 && v <= 65535)
            return static_cast<quint16>(v);
        qWarning() << "[Automation] MEOW_AUTOMATION_PORT invalide :" << env;
    }

    return 0; // aucun port demandé → pas de serveur
}

AutomationServer *AutomationServer::maybeCreate(const QStringList &args, QObject *parent)
{
    const quint16 port = resolvePort(args);
    if (port == 0)
        return nullptr;
    return new AutomationServer(port, parent);
}

// ============================================================================
// Connexions WebSocket
// ============================================================================

void AutomationServer::onNewConnection()
{
    while (m_server->hasPendingConnections()) {
        QWebSocket *sock = m_server->nextPendingConnection();
        // Double garde : seule la loopback est acceptée.
        const QHostAddress peer = sock->peerAddress();
        if (peer != QHostAddress(QHostAddress::LocalHost)
            && peer != QHostAddress(QHostAddress::LocalHostIPv6)) {
            qWarning() << "[Automation] Connexion non-loopback rejetée :" << peer;
            sock->close();
            sock->deleteLater();
            continue;
        }
        connect(sock, &QWebSocket::textMessageReceived,
                this, &AutomationServer::onTextMessageReceived);
        connect(sock, &QWebSocket::disconnected,
                this, &AutomationServer::onSocketDisconnected);
        m_clients.append(sock);
        qInfo() << "[Automation] Client connecté (" << m_clients.size() << "actifs )";
    }
}

void AutomationServer::onSocketDisconnected()
{
    QWebSocket *sock = qobject_cast<QWebSocket *>(sender());
    if (!sock)
        return;
    m_clients.removeAll(sock);
    sock->deleteLater();
    qInfo() << "[Automation] Client déconnecté (" << m_clients.size() << "restants )";
}

void AutomationServer::onTextMessageReceived(const QString &message)
{
    QWebSocket *client = qobject_cast<QWebSocket *>(sender());
    if (!client)
        return;

    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(message.toUtf8(), &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject()) {
        sendResponse(client, QJsonValue::Null, false,
                     QStringLiteral("JSON invalide: %1").arg(perr.errorString()));
        return;
    }

    const QJsonObject obj = doc.object();
    const QJsonValue id = obj.value(QStringLiteral("id"));
    const QString cmd = obj.value(QStringLiteral("cmd")).toString();
    const QJsonObject params = obj.value(QStringLiteral("params")).toObject();

    if (cmd.isEmpty()) {
        sendResponse(client, id, false, QStringLiteral("Champ 'cmd' manquant"));
        return;
    }

    bool ok = true;
    bool deferred = false;
    QString error;
    const QJsonValue result = dispatch(cmd, params, ok, error, client, id, deferred);

    if (deferred)
        return; // la commande répondra elle-même (waitFor)

    if (ok)
        sendResponse(client, id, true, result);
    else
        sendResponse(client, id, false, error);
}

// ============================================================================
// Dispatch
// ============================================================================

QJsonValue AutomationServer::dispatch(const QString &cmd, const QJsonObject &params,
                                      bool &ok, QString &error, QWebSocket *client,
                                      const QJsonValue &id, bool &deferred)
{
    ok = true;
    deferred = false;

    if (cmd == QLatin1String("ping"))        return cmdPing(params, ok, error);
    if (cmd == QLatin1String("tree"))        return cmdTree(params, ok, error);
    if (cmd == QLatin1String("find"))        return cmdFind(params, ok, error);
    if (cmd == QLatin1String("get"))         return cmdGet(params, ok, error);
    if (cmd == QLatin1String("set"))         return cmdSet(params, ok, error);
    if (cmd == QLatin1String("invoke"))      return cmdInvoke(params, ok, error);
    if (cmd == QLatin1String("click") || cmd == QLatin1String("doubleClick")
        || cmd == QLatin1String("move") || cmd == QLatin1String("press")
        || cmd == QLatin1String("release"))  return cmdMouse(cmd, params, ok, error);
    if (cmd == QLatin1String("wheel"))       return cmdWheel(params, ok, error);
    if (cmd == QLatin1String("keys"))        return cmdKeys(params, ok, error);
    if (cmd == QLatin1String("screenshot"))  return cmdScreenshot(params, ok, error);
    if (cmd == QLatin1String("quit"))        return cmdQuit(params, ok, error);
    if (cmd == QLatin1String("waitFor")) {
        deferred = true;
        cmdWaitFor(params, client, id);
        return QJsonValue();
    }

    ok = false;
    error = QStringLiteral("Commande inconnue: %1").arg(cmd);
    return QJsonValue();
}

// ============================================================================
// Helpers fenêtres
// ============================================================================

QList<QQuickWindow *> AutomationServer::quickWindows() const
{
    QList<QQuickWindow *> out;
    const QList<QWindow *> tops = QGuiApplication::topLevelWindows();
    for (QWindow *w : tops) {
        if (auto *qw = qobject_cast<QQuickWindow *>(w))
            out.append(qw);
    }
    return out;
}

QQuickWindow *AutomationServer::primaryWindow() const
{
    const QList<QQuickWindow *> wins = quickWindows();

    // main.cpp instancie une QQuickWindow « sonde » (détection du backend
    // graphique) qui n'est jamais affichée ni peuplée : son contentItem n'a
    // aucun enfant. Il faut l'écarter pour ne pas masquer la vraie fenêtre
    // de l'ApplicationWindow chargée par l'engine QML.
    auto hasContent = [](QQuickWindow *w) {
        return w->contentItem() && !w->contentItem()->childItems().isEmpty();
    };

    // 1) Fenêtre visible ET peuplée.
    for (QQuickWindow *w : wins) {
        if (w->isVisible() && hasContent(w))
            return w;
    }
    // 2) Fenêtre peuplée (même non encore « visible » côté OS, ex. headless).
    for (QQuickWindow *w : wins) {
        if (hasContent(w))
            return w;
    }
    // 3) Fenêtre visible.
    for (QQuickWindow *w : wins) {
        if (w->isVisible())
            return w;
    }
    return wins.isEmpty() ? nullptr : wins.first();
}

// ============================================================================
// ping
// ============================================================================

QJsonValue AutomationServer::cmdPing(const QJsonObject &, bool &ok, QString &)
{
    ok = true;
    QJsonObject res;
    res["app"] = QCoreApplication::applicationName();
    res["version"] = QCoreApplication::applicationVersion();
    res["pid"] = static_cast<qint64>(QCoreApplication::applicationPid());

    // Détecter l'instance depuis le nom de l'app ("Meownopoly_2" → 2).
    int instance = 1;
    const QString appName = QCoreApplication::applicationName();
    const QRegularExpression re(QStringLiteral("_(\\d+)$"));
    const QRegularExpressionMatch m = re.match(appName);
    if (m.hasMatch())
        instance = m.captured(1).toInt();
    res["instance"] = instance;

    QQuickWindow *w = primaryWindow();
    if (w) {
        res["windowTitle"] = w->title();
        res["windowWidth"] = w->width();
        res["windowHeight"] = w->height();
        // Scène QML courante : meilleur effort via le StackView principal.
        QString scene;
        QString err;
        QObject *stack = nullptr;
        {
            QList<QObject *> found;
            findRecursive(w->contentItem(), QStringLiteral("mainStackView"),
                          QString(), found);
            if (!found.isEmpty())
                stack = found.first();
        }
        if (stack) {
            const QVariant cur = stack->property("currentItem");
            QObject *curItem = cur.value<QObject *>();
            if (curItem) {
                scene = curItem->objectName();
                if (scene.isEmpty())
                    scene = QString::fromLatin1(curItem->metaObject()->className());
            }
        }
        res["currentScene"] = scene;
        Q_UNUSED(err);
    }
    res["windowCount"] = quickWindows().size();
    return res;
}

// ============================================================================
// tree
// ============================================================================

QJsonValue AutomationServer::cmdTree(const QJsonObject &params, bool &ok, QString &error)
{
    const int maxDepth = params.contains(QStringLiteral("depth"))
        ? params.value(QStringLiteral("depth")).toInt() : 3;
    const QString filter = params.value(QStringLiteral("filter")).toString();

    QObject *root = nullptr;
    if (params.contains(QStringLiteral("target")) || params.contains(QStringLiteral("objectName"))
        || params.contains(QStringLiteral("id"))) {
        root = resolveTarget(params, error);
        if (!root) {
            ok = false;
            return QJsonValue();
        }
    }

    QJsonArray windows;
    if (root) {
        windows.append(objectToJson(root, 0, maxDepth, filter));
    } else {
        const QList<QQuickWindow *> wins = quickWindows();
        if (wins.isEmpty()) {
            ok = false;
            error = QStringLiteral("Aucune QQuickWindow top-level");
            return QJsonValue();
        }
        for (QQuickWindow *w : wins) {
            QJsonObject wj = objectToJson(w, 0, maxDepth, filter);
            wj["windowTitle"] = w->title();
            windows.append(wj);
        }
    }
    ok = true;
    return windows;
}

QJsonObject AutomationServer::objectToJson(QObject *obj, int depth, int maxDepth,
                                           const QString &filter) const
{
    QJsonObject j;
    if (!obj)
        return j;

    j["objectName"] = obj->objectName();
    j["className"] = QString::fromLatin1(obj->metaObject()->className());
    j["id"] = encodeId(obj);

    if (auto *item = qobject_cast<QQuickItem *>(obj)) {
        j["geometry"] = itemGeometry(item);
        j["visible"] = item->isVisible();
        j["enabled"] = item->isEnabled();
    } else if (auto *win = qobject_cast<QQuickWindow *>(obj)) {
        QJsonObject g;
        g["x"] = win->x();
        g["y"] = win->y();
        g["width"] = win->width();
        g["height"] = win->height();
        j["geometry"] = g;
        j["visible"] = win->isVisible();
    }

    if (depth >= maxDepth)
        return j;

    QJsonArray children;
    // Pour une fenêtre, le vrai arbre visuel part de contentItem.
    QObjectList kids;
    if (auto *win = qobject_cast<QQuickWindow *>(obj)) {
        if (win->contentItem())
            kids = win->contentItem()->childItems().isEmpty()
                       ? win->contentItem()->children()
                       : QObjectList();
        // childItems() renvoie des QQuickItem*; on les ajoute explicitement.
        if (win->contentItem()) {
            const QList<QQuickItem *> ci = win->contentItem()->childItems();
            for (QQuickItem *c : ci)
                kids.append(c);
        }
    } else if (auto *item = qobject_cast<QQuickItem *>(obj)) {
        const QList<QQuickItem *> ci = item->childItems();
        for (QQuickItem *c : ci)
            kids.append(c);
    } else {
        kids = obj->children();
    }

    for (QObject *c : std::as_const(kids)) {
        if (!filter.isEmpty()) {
            // Filtre : ne descendre/inclure que si className ou objectName matche
            // quelque part dans le sous-arbre. Simplification : on inclut toujours
            // et on laisse le filtre s'appliquer au noeud lui-même via match partiel.
            const QString cn = QString::fromLatin1(c->metaObject()->className());
            const bool selfMatch = cn.contains(filter, Qt::CaseInsensitive)
                                   || c->objectName().contains(filter, Qt::CaseInsensitive);
            // On descend quand même pour trouver d'éventuels descendants matchants.
            QJsonObject cj = objectToJson(c, depth + 1, maxDepth, filter);
            const bool hasChildren = cj.value(QStringLiteral("children")).toArray().size() > 0;
            if (selfMatch || hasChildren)
                children.append(cj);
        } else {
            children.append(objectToJson(c, depth + 1, maxDepth, filter));
        }
    }
    if (!children.isEmpty())
        j["children"] = children;
    return j;
}

QJsonObject AutomationServer::itemGeometry(QQuickItem *item) const
{
    QJsonObject g;
    g["x"] = item->x();
    g["y"] = item->y();
    g["width"] = item->width();
    g["height"] = item->height();

    // Coordonnées scène (centre + top-left) pour le ciblage souris.
    const QPointF tl = item->mapToScene(QPointF(0, 0));
    const QPointF center = item->mapToScene(QPointF(item->width() / 2.0, item->height() / 2.0));
    QJsonObject scene;
    scene["x"] = tl.x();
    scene["y"] = tl.y();
    scene["centerX"] = center.x();
    scene["centerY"] = center.y();
    g["scene"] = scene;
    return g;
}

// ============================================================================
// find
// ============================================================================

void AutomationServer::findRecursive(QObject *root, const QString &objectName,
                                     const QString &className,
                                     QList<QObject *> &out) const
{
    if (!root)
        return;

    bool nameOk = objectName.isEmpty() || root->objectName() == objectName;
    bool classOk = className.isEmpty()
                   || QString::fromLatin1(root->metaObject()->className())
                          .contains(className, Qt::CaseInsensitive);
    if (!objectName.isEmpty() ? nameOk && classOk
                              : (!className.isEmpty() && classOk)) {
        out.append(root);
    }

    // Descente par l'arbre visuel quand possible.
    if (auto *item = qobject_cast<QQuickItem *>(root)) {
        const QList<QQuickItem *> ci = item->childItems();
        for (QQuickItem *c : ci)
            findRecursive(c, objectName, className, out);
    } else {
        const QObjectList kids = root->children();
        for (QObject *c : kids)
            findRecursive(c, objectName, className, out);
    }
}

QJsonValue AutomationServer::cmdFind(const QJsonObject &params, bool &ok, QString &error)
{
    const QString objectName = params.value(QStringLiteral("objectName")).toString();
    const QString className = params.value(QStringLiteral("className")).toString();
    if (objectName.isEmpty() && className.isEmpty()) {
        ok = false;
        error = QStringLiteral("'objectName' ou 'className' requis");
        return QJsonValue();
    }

    const QList<QQuickWindow *> wins = quickWindows();
    QList<QObject *> found;
    for (QQuickWindow *w : wins) {
        findRecursive(w->contentItem(), objectName, className, found);
    }

    QJsonArray arr;
    for (QObject *obj : std::as_const(found)) {
        QJsonObject o;
        o["objectName"] = obj->objectName();
        o["className"] = QString::fromLatin1(obj->metaObject()->className());
        o["id"] = encodeId(obj);
        if (auto *item = qobject_cast<QQuickItem *>(obj)) {
            o["geometry"] = itemGeometry(item);
            o["visible"] = item->isVisible();
            o["enabled"] = item->isEnabled();
        }
        arr.append(o);
    }
    ok = true;
    return arr;
}

// ============================================================================
// Résolution de cible
// ============================================================================

QString AutomationServer::encodeId(const QObject *obj)
{
    return QStringLiteral("0x%1").arg(reinterpret_cast<quintptr>(obj),
                                      0, 16);
}

QObject *AutomationServer::decodeId(const QString &id) const
{
    bool conv = false;
    const quintptr ptr = id.startsWith(QLatin1String("0x"))
        ? id.mid(2).toULongLong(&conv, 16)
        : id.toULongLong(&conv, 16);
    if (!conv || ptr == 0)
        return nullptr;
    QObject *candidate = reinterpret_cast<QObject *>(ptr);

    // Validation : on vérifie que le pointeur existe encore dans l'arbre courant
    // (évite un use-after-free si l'item a été détruit entre deux commandes).
    const QList<QQuickWindow *> wins = quickWindows();
    std::function<bool(QObject *)> contains = [&](QObject *root) -> bool {
        if (root == candidate)
            return true;
        if (auto *item = qobject_cast<QQuickItem *>(root)) {
            const QList<QQuickItem *> ci = item->childItems();
            for (QQuickItem *c : ci)
                if (contains(c))
                    return true;
        } else {
            const QObjectList kids = root->children();
            for (QObject *c : kids)
                if (contains(c))
                    return true;
        }
        return false;
    };
    for (QQuickWindow *w : wins) {
        if (w == candidate)
            return candidate;
        if (w->contentItem() && contains(w->contentItem()))
            return candidate;
    }
    return nullptr;
}

QObject *AutomationServer::resolveTarget(const QJsonObject &params, QString &error) const
{
    // 1) id pointeur explicite
    const QString id = params.value(QStringLiteral("id")).toString();
    if (!id.isEmpty()) {
        QObject *obj = decodeId(id);
        if (!obj) {
            error = QStringLiteral("id introuvable ou objet détruit: %1").arg(id);
            return nullptr;
        }
        return obj;
    }
    // 2) "target" peut être un id ou un objectName
    const QString target = params.value(QStringLiteral("target")).toString();
    const QString objectName = !target.isEmpty()
        ? target : params.value(QStringLiteral("objectName")).toString();
    if (objectName.isEmpty()) {
        error = QStringLiteral("Cible manquante ('objectName', 'target' ou 'id')");
        return nullptr;
    }
    if (objectName.startsWith(QLatin1String("0x"))) {
        QObject *obj = decodeId(objectName);
        if (obj)
            return obj;
    }
    const QString className = params.value(QStringLiteral("className")).toString();
    const QList<QQuickWindow *> wins = quickWindows();
    QList<QObject *> found;
    for (QQuickWindow *w : wins)
        findRecursive(w->contentItem(), objectName, className, found);
    if (found.isEmpty()) {
        error = QStringLiteral("Aucun objet avec objectName='%1'").arg(objectName);
        return nullptr;
    }
    return found.first();
}

// ============================================================================
// get / set
// ============================================================================

QJsonValue AutomationServer::variantToJson(const QVariant &v)
{
    // Les fonctions JS QML peuvent retourner un QJSValue (même quand le
    // meta-type annoncé est QVariant). On le déballe en QVariant natif avant
    // la conversion JSON, sinon QJsonValue::fromVariant produit `null`.
    if (v.metaType().id() == qMetaTypeId<QJSValue>()) {
        const QJSValue jsv = v.value<QJSValue>();
        return QJsonValue::fromVariant(jsv.toVariant());
    }
    return QJsonValue::fromVariant(v);
}

QVariant AutomationServer::jsonToVariant(const QJsonValue &v)
{
    return v.toVariant();
}

QJsonValue AutomationServer::cmdGet(const QJsonObject &params, bool &ok, QString &error)
{
    QObject *obj = resolveTarget(params, error);
    if (!obj) {
        ok = false;
        return QJsonValue();
    }
    const QString prop = params.value(QStringLiteral("property")).toString();
    if (prop.isEmpty()) {
        ok = false;
        error = QStringLiteral("'property' requis");
        return QJsonValue();
    }
    const QVariant val = obj->property(prop.toUtf8().constData());
    if (!val.isValid()) {
        ok = false;
        error = QStringLiteral("Propriété inconnue ou invalide: %1").arg(prop);
        return QJsonValue();
    }
    ok = true;
    QJsonObject res;
    res["property"] = prop;
    res["value"] = variantToJson(val);
    res["typeName"] = QString::fromLatin1(val.typeName());
    return res;
}

QJsonValue AutomationServer::cmdSet(const QJsonObject &params, bool &ok, QString &error)
{
    QObject *obj = resolveTarget(params, error);
    if (!obj) {
        ok = false;
        return QJsonValue();
    }
    const QString prop = params.value(QStringLiteral("property")).toString();
    if (prop.isEmpty()) {
        ok = false;
        error = QStringLiteral("'property' requis");
        return QJsonValue();
    }
    if (!params.contains(QStringLiteral("value"))) {
        ok = false;
        error = QStringLiteral("'value' requis");
        return QJsonValue();
    }
    const QVariant newVal = jsonToVariant(params.value(QStringLiteral("value")));
    const bool done = obj->setProperty(prop.toUtf8().constData(), newVal);
    if (!done) {
        // setProperty renvoie false pour une propriété dynamique nouvelle, mais
        // aussi en cas d'échec réel. On relit pour confirmer.
        ok = true;
        QJsonObject res;
        res["property"] = prop;
        res["set"] = false;
        res["value"] = variantToJson(obj->property(prop.toUtf8().constData()));
        return res;
    }
    ok = true;
    QJsonObject res;
    res["property"] = prop;
    res["set"] = true;
    res["value"] = variantToJson(obj->property(prop.toUtf8().constData()));
    return res;
}

// ============================================================================
// invoke
// ============================================================================

QJsonValue AutomationServer::cmdInvoke(const QJsonObject &params, bool &ok, QString &error)
{
    QObject *obj = resolveTarget(params, error);
    if (!obj) {
        ok = false;
        return QJsonValue();
    }
    const QString method = params.value(QStringLiteral("method")).toString();
    if (method.isEmpty()) {
        ok = false;
        error = QStringLiteral("'method' requis");
        return QJsonValue();
    }
    const QJsonArray argsArr = params.value(QStringLiteral("args")).toArray();

    // Recherche du premier match par arité dans le meta-object.
    const QMetaObject *mo = obj->metaObject();
    QMetaMethod chosen;
    bool foundMethod = false;
    for (int i = 0; i < mo->methodCount(); ++i) {
        const QMetaMethod mm = mo->method(i);
        if (QString::fromLatin1(mm.name()) != method)
            continue;
        if (mm.parameterCount() != argsArr.size())
            continue;
        if (mm.methodType() != QMetaMethod::Method
            && mm.methodType() != QMetaMethod::Slot)
            continue;
        chosen = mm;
        foundMethod = true;
        break;
    }
    if (!foundMethod) {
        ok = false;
        error = QStringLiteral("Méthode invocable '%1' avec %2 arg(s) introuvable")
                    .arg(method).arg(argsArr.size());
        return QJsonValue();
    }

    QJsonObject res;
    res["method"] = method;

    // Les fonctions JS QML exposent tous leurs paramètres et leur retour comme
    // `QVariant` dans le meta-object (le moteur convertit en/depuis QJSValue).
    // Pour ces méthodes, `QMetaMethod::invoke` avec QGenericReturnArgument typé
    // QVariant ne récupère PAS la valeur (le moteur écrit un QJSValue que le
    // QVariant retour ne déballe pas). On passe donc par la voie QVariant pure :
    // Q_RETURN_ARG(QVariant) + Q_ARG(QVariant) — robuste pour les fonctions QML.
    const int retType = chosen.returnType();
    const bool qmlStyleReturn = (retType == QMetaType::QVariant);
    bool qmlStyleArgs = true;
    for (int i = 0; i < chosen.parameterCount(); ++i) {
        if (chosen.parameterType(i) != QMetaType::QVariant) {
            qmlStyleArgs = false;
            break;
        }
    }

    if (qmlStyleArgs && argsArr.size() <= 10) {
        // Voie QML : pour les fonctions JS, le meta-object annonce des
        // paramètres et un retour de type `QVariant`. On doit donc déclarer
        // les QGenericArgument/QGenericReturnArgument AVEC le nom de type
        // "QVariant" exact (sinon `QMetaMethod::invoke` rejette par mismatch
        // de signature). Le moteur QML écrit ensuite la valeur de retour dans
        // ce QVariant — éventuellement sous forme de QJSValue, déballé par
        // `variantToJson`.
        QVariantList vargs;
        vargs.reserve(argsArr.size());
        for (int i = 0; i < argsArr.size(); ++i)
            vargs.append(jsonToVariant(argsArr.at(i)));

        QGenericArgument genArgs[10];
        for (int i = 0; i < vargs.size(); ++i)
            genArgs[i] = QGenericArgument("QVariant", &vargs[i]);

        bool invoked = false;
        if (qmlStyleReturn) {
            QVariant retVal;
            QGenericReturnArgument ret("QVariant", &retVal);
            invoked = chosen.invoke(obj, Qt::DirectConnection, ret,
                                    genArgs[0], genArgs[1], genArgs[2], genArgs[3],
                                    genArgs[4], genArgs[5], genArgs[6], genArgs[7],
                                    genArgs[8], genArgs[9]);
            res["result"] = invoked ? variantToJson(retVal) : QJsonValue::Null;
        } else {
            invoked = chosen.invoke(obj, Qt::DirectConnection,
                                    genArgs[0], genArgs[1], genArgs[2], genArgs[3],
                                    genArgs[4], genArgs[5], genArgs[6], genArgs[7],
                                    genArgs[8], genArgs[9]);
            res["result"] = QJsonValue::Null;
        }
        if (!invoked) {
            ok = false;
            error = QStringLiteral("Échec de l'invocation QML de '%1'").arg(method);
            return QJsonValue();
        }
        ok = true;
        return res;
    }

    // Voie C++ générique (Q_INVOKABLE / slot typé) : conversion par signature.
    QVariantList vargs;
    for (int i = 0; i < argsArr.size(); ++i) {
        QVariant v = jsonToVariant(argsArr.at(i));
        const int targetType = chosen.parameterType(i);
        if (targetType != QMetaType::UnknownType && v.metaType().id() != targetType) {
            QVariant converted = v;
            if (converted.convert(QMetaType(targetType)))
                v = converted;
        }
        vargs.append(v);
    }

    QGenericArgument genArgs[10];
    // On garde les QVariant vivants le temps de l'appel.
    for (int i = 0; i < vargs.size() && i < 10; ++i) {
        genArgs[i] = QGenericArgument(vargs[i].typeName(),
                                      const_cast<void *>(vargs[i].constData()));
    }

    // Préparer le retour.
    QVariant retVal;
    bool invoked = false;

    if (retType != QMetaType::Void && retType != QMetaType::UnknownType) {
        retVal = QVariant(QMetaType(retType), nullptr);
        QGenericReturnArgument ret(QMetaType(retType).name(), retVal.data());
        invoked = chosen.invoke(obj, Qt::DirectConnection, ret,
                                genArgs[0], genArgs[1], genArgs[2], genArgs[3],
                                genArgs[4], genArgs[5], genArgs[6], genArgs[7],
                                genArgs[8], genArgs[9]);
        if (invoked)
            res["result"] = variantToJson(retVal);
    } else {
        invoked = chosen.invoke(obj, Qt::DirectConnection,
                                genArgs[0], genArgs[1], genArgs[2], genArgs[3],
                                genArgs[4], genArgs[5], genArgs[6], genArgs[7],
                                genArgs[8], genArgs[9]);
        res["result"] = QJsonValue::Null;
    }

    if (!invoked) {
        ok = false;
        error = QStringLiteral("Échec de l'invocation de '%1'").arg(method);
        return QJsonValue();
    }
    ok = true;
    return res;
}

// ============================================================================
// Synthèse souris : click / doubleClick / move / press / release
// ============================================================================

QJsonValue AutomationServer::cmdMouse(const QString &cmd, const QJsonObject &params,
                                      bool &ok, QString &error)
{
    QQuickWindow *win = primaryWindow();
    if (!win) {
        ok = false;
        error = QStringLiteral("Aucune fenêtre");
        return QJsonValue();
    }

    QPointF scenePos;
    // Cible : item (centre + offset) ou coordonnées scène explicites.
    if (params.contains(QStringLiteral("x")) && params.contains(QStringLiteral("y"))
        && !params.contains(QStringLiteral("objectName"))
        && !params.contains(QStringLiteral("id"))
        && !params.contains(QStringLiteral("target"))) {
        scenePos = QPointF(params.value(QStringLiteral("x")).toDouble(),
                           params.value(QStringLiteral("y")).toDouble());
    } else {
        QObject *obj = resolveTarget(params, error);
        if (!obj) {
            ok = false;
            return QJsonValue();
        }
        auto *item = qobject_cast<QQuickItem *>(obj);
        if (!item) {
            ok = false;
            error = QStringLiteral("La cible n'est pas un QQuickItem");
            return QJsonValue();
        }
        double offX = item->width() / 2.0;
        double offY = item->height() / 2.0;
        if (params.contains(QStringLiteral("offsetX")))
            offX = params.value(QStringLiteral("offsetX")).toDouble();
        if (params.contains(QStringLiteral("offsetY")))
            offY = params.value(QStringLiteral("offsetY")).toDouble();
        scenePos = item->mapToScene(QPointF(offX, offY));
    }

    const Qt::MouseButton button = Qt::LeftButton;

    auto post = [&](QEvent::Type t, Qt::MouseButtons buttons) {
        QMouseEvent ev(t, scenePos, win->mapToGlobal(scenePos.toPoint()),
                       button, buttons, Qt::NoModifier);
        QCoreApplication::sendEvent(win, &ev);
    };

    if (cmd == QLatin1String("move")) {
        post(QEvent::MouseMove, Qt::NoButton);
    } else if (cmd == QLatin1String("press")) {
        post(QEvent::MouseButtonPress, button);
    } else if (cmd == QLatin1String("release")) {
        post(QEvent::MouseButtonRelease, Qt::NoButton);
    } else if (cmd == QLatin1String("click")) {
        post(QEvent::MouseButtonPress, button);
        post(QEvent::MouseButtonRelease, Qt::NoButton);
    } else if (cmd == QLatin1String("doubleClick")) {
        post(QEvent::MouseButtonPress, button);
        post(QEvent::MouseButtonRelease, Qt::NoButton);
        post(QEvent::MouseButtonDblClick, button);
        post(QEvent::MouseButtonRelease, Qt::NoButton);
    }

    ok = true;
    QJsonObject res;
    res["action"] = cmd;
    res["sceneX"] = scenePos.x();
    res["sceneY"] = scenePos.y();
    return res;
}

QJsonValue AutomationServer::cmdWheel(const QJsonObject &params, bool &ok, QString &error)
{
    QQuickWindow *win = primaryWindow();
    if (!win) {
        ok = false;
        error = QStringLiteral("Aucune fenêtre");
        return QJsonValue();
    }

    QPointF scenePos;
    if (params.contains(QStringLiteral("objectName")) || params.contains(QStringLiteral("id"))
        || params.contains(QStringLiteral("target"))) {
        QObject *obj = resolveTarget(params, error);
        if (!obj) {
            ok = false;
            return QJsonValue();
        }
        auto *item = qobject_cast<QQuickItem *>(obj);
        if (item)
            scenePos = item->mapToScene(QPointF(item->width() / 2.0, item->height() / 2.0));
    }
    if (params.contains(QStringLiteral("x")) && params.contains(QStringLiteral("y"))) {
        scenePos = QPointF(params.value(QStringLiteral("x")).toDouble(),
                           params.value(QStringLiteral("y")).toDouble());
    }

    const int angleDelta = params.contains(QStringLiteral("delta"))
        ? params.value(QStringLiteral("delta")).toInt() : 120;

    QWheelEvent ev(scenePos, win->mapToGlobal(scenePos.toPoint()),
                   QPoint(0, 0), QPoint(0, angleDelta),
                   Qt::NoButton, Qt::NoModifier,
                   Qt::NoScrollPhase, false);
    QCoreApplication::sendEvent(win, &ev);

    ok = true;
    QJsonObject res;
    res["delta"] = angleDelta;
    res["sceneX"] = scenePos.x();
    res["sceneY"] = scenePos.y();
    return res;
}

// ============================================================================
// keys : synthèse de touches / texte
// ============================================================================

QJsonValue AutomationServer::cmdKeys(const QJsonObject &params, bool &ok, QString &error)
{
    QQuickWindow *win = primaryWindow();
    if (!win) {
        ok = false;
        error = QStringLiteral("Aucune fenêtre");
        return QJsonValue();
    }

    // Si une cible est fournie, lui donner le focus d'abord.
    if (params.contains(QStringLiteral("objectName")) || params.contains(QStringLiteral("id"))
        || params.contains(QStringLiteral("target"))) {
        QString terr;
        QObject *obj = resolveTarget(params, terr);
        if (auto *item = qobject_cast<QQuickItem *>(obj))
            item->forceActiveFocus();
    }

    // Mode texte : tape une chaîne caractère par caractère.
    if (params.contains(QStringLiteral("text"))) {
        const QString text = params.value(QStringLiteral("text")).toString();
        for (const QChar &ch : text) {
            QKeyEvent press(QEvent::KeyPress, 0, Qt::NoModifier, QString(ch));
            QCoreApplication::sendEvent(win, &press);
            QKeyEvent release(QEvent::KeyRelease, 0, Qt::NoModifier, QString(ch));
            QCoreApplication::sendEvent(win, &release);
        }
        ok = true;
        QJsonObject res;
        res["text"] = text;
        return res;
    }

    // Mode touche : un Qt::Key (par valeur numérique) + modifiers optionnels.
    if (params.contains(QStringLiteral("key"))) {
        const int key = params.value(QStringLiteral("key")).toInt();
        Qt::KeyboardModifiers mods = Qt::NoModifier;
        const QJsonArray modsArr = params.value(QStringLiteral("modifiers")).toArray();
        for (const QJsonValue &mv : modsArr) {
            const QString m = mv.toString().toLower();
            if (m == QLatin1String("ctrl") || m == QLatin1String("control"))
                mods |= Qt::ControlModifier;
            else if (m == QLatin1String("shift"))
                mods |= Qt::ShiftModifier;
            else if (m == QLatin1String("alt"))
                mods |= Qt::AltModifier;
            else if (m == QLatin1String("meta"))
                mods |= Qt::MetaModifier;
        }
        QKeyEvent press(QEvent::KeyPress, key, mods);
        QCoreApplication::sendEvent(win, &press);
        QKeyEvent release(QEvent::KeyRelease, key, mods);
        QCoreApplication::sendEvent(win, &release);
        ok = true;
        QJsonObject res;
        res["key"] = key;
        return res;
    }

    ok = false;
    error = QStringLiteral("'text' ou 'key' requis");
    return QJsonValue();
}

// ============================================================================
// screenshot
// ============================================================================

QJsonValue AutomationServer::cmdScreenshot(const QJsonObject &params, bool &ok, QString &error)
{
    QQuickWindow *win = primaryWindow();
    if (!win) {
        ok = false;
        error = QStringLiteral("Aucune fenêtre");
        return QJsonValue();
    }

    const QImage img = win->grabWindow();
    if (img.isNull()) {
        ok = false;
        error = QStringLiteral("grabWindow() a renvoyé une image vide");
        return QJsonValue();
    }

    QString path = params.value(QStringLiteral("path")).toString();
    if (path.isEmpty()) {
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
        const QString fn = QStringLiteral("meow_screenshot_%1.png")
            .arg(QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_hhmmss_zzz")));
        path = QDir(dir).absoluteFilePath(fn);
    }
    const QString absPath = QFileInfo(path).absoluteFilePath();
    QDir().mkpath(QFileInfo(absPath).absolutePath());

    if (!img.save(absPath, "PNG")) {
        ok = false;
        error = QStringLiteral("Échec de la sauvegarde du PNG: %1").arg(absPath);
        return QJsonValue();
    }

    ok = true;
    QJsonObject res;
    res["path"] = absPath;
    res["width"] = img.width();
    res["height"] = img.height();
    return res;
}

// ============================================================================
// quit
// ============================================================================

QJsonValue AutomationServer::cmdQuit(const QJsonObject &, bool &ok, QString &)
{
    ok = true;
    // Différer pour que la réponse parte avant la fermeture.
    QTimer::singleShot(150, qApp, []() {
        QCoreApplication::quit();
    });
    QJsonObject res;
    res["quitting"] = true;
    return res;
}

// ============================================================================
// waitFor (réponse différée par polling)
// ============================================================================

void AutomationServer::cmdWaitFor(const QJsonObject &params, QWebSocket *client,
                                  const QJsonValue &id)
{
    const QString objectName = params.value(QStringLiteral("objectName")).toString();
    const QString prop = params.value(QStringLiteral("property")).toString();
    const bool hasValue = params.contains(QStringLiteral("value"));
    const QVariant wantValue = hasValue
        ? jsonToVariant(params.value(QStringLiteral("value"))) : QVariant();
    const bool wantVisible = params.value(QStringLiteral("visible")).toBool(false);
    const int timeoutMs = params.contains(QStringLiteral("timeout"))
        ? params.value(QStringLiteral("timeout")).toInt() : 5000;
    const int intervalMs = 100;

    if (objectName.isEmpty()) {
        sendResponse(client, id, false, QStringLiteral("'objectName' requis pour waitFor"));
        return;
    }

    // Capture pour valider que le client est toujours vivant lors du callback.
    QPointer<QWebSocket> clientPtr(client);
    auto *timer = new QTimer(this);
    auto *elapsed = new qint64(0);
    timer->setInterval(intervalMs);

    auto check = [this, timer, elapsed, clientPtr, id, objectName, prop, hasValue,
                  wantValue, wantVisible, timeoutMs, intervalMs]() {
        if (!clientPtr) {
            timer->stop();
            timer->deleteLater();
            return;
        }

        // Recherche de l'objet.
        const QList<QQuickWindow *> wins = quickWindows();
        QList<QObject *> found;
        for (QQuickWindow *w : wins)
            findRecursive(w->contentItem(), objectName, QString(), found);

        bool satisfied = false;
        QObject *obj = found.isEmpty() ? nullptr : found.first();

        if (obj) {
            if (!prop.isEmpty() && hasValue) {
                const QVariant cur = obj->property(prop.toUtf8().constData());
                QVariant want = wantValue;
                if (want.canConvert(cur.metaType()))
                    want.convert(cur.metaType());
                satisfied = (cur == want);
            } else if (wantVisible) {
                if (auto *item = qobject_cast<QQuickItem *>(obj))
                    satisfied = item->isVisible();
                else
                    satisfied = true;
            } else {
                // Juste l'existence.
                satisfied = true;
            }
        }

        if (satisfied) {
            timer->stop();
            timer->deleteLater();
            QJsonObject res;
            res["objectName"] = objectName;
            res["found"] = (obj != nullptr);
            res["id"] = obj ? encodeId(obj) : QString();
            res["waitedMs"] = static_cast<double>(*elapsed);
            delete elapsed;
            sendResponse(clientPtr, id, true, res);
            return;
        }

        *elapsed += intervalMs;
        if (*elapsed >= timeoutMs) {
            timer->stop();
            timer->deleteLater();
            const qint64 waited = *elapsed;
            delete elapsed;
            sendResponse(clientPtr, id, false,
                         QStringLiteral("Timeout (%1 ms) en attendant '%2'")
                             .arg(waited).arg(objectName));
        }
    };

    connect(timer, &QTimer::timeout, this, check);
    timer->start();
    // Un premier check immédiat (sans attendre le 1er intervalle).
    QTimer::singleShot(0, this, check);
}

// ============================================================================
// Réponse
// ============================================================================

void AutomationServer::sendResponse(QWebSocket *client, const QJsonValue &id, bool ok,
                                    const QJsonValue &resultOrError)
{
    if (!client)
        return;
    QJsonObject resp;
    resp["id"] = id;
    resp["ok"] = ok;
    if (ok)
        resp["result"] = resultOrError;
    else
        resp["error"] = resultOrError;
    const QString payload = QString::fromUtf8(
        QJsonDocument(resp).toJson(QJsonDocument::Compact));
    client->sendTextMessage(payload);
}
