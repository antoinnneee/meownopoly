#include "static_validator.h"

// ============================================================================
// Implémentation du préfiltre statique P0 — voir le header pour le contrat,
// la table des codes d'erreur et le choix « analyse lexicale, pas de moteur ».
//
// Pipeline interne :
//   1. hash SHA-256 (toujours calculé, même en échec) ;
//   2. contrôle de taille (source_too_large) ;
//   3. « blanking » : commentaires et littéraux de chaîne remplacés par des
//      espaces (positions et retours-ligne préservés), interpolations
//      ${...} des template literals conservées comme code. Un littéral non
//      terminé → parse_failed et ARRÊT des contrôles de contenu (le buffer
//      blanchi n'est pas fiable — échec fermé) ;
//   4. équilibre {} () [] + objet racine (parse_failed) ;
//   5. imports (import_forbidden) ; 6. tokens JS (js_forbidden) ;
//   7. Timer littéral (timer_interval_too_low) ; 8. requiresModules (D41,
//      missing_module retryable) ; 9. collecte listensTo.
//
// Limitation connue (documentée) : les littéraux regex JS (/…/) ne sont pas
// tokenisés — un slash de division suivi de quotes peut, au pire, blanchir
// trop de texte ou déclencher un parse_failed (jamais un pass indu).
// ============================================================================

#include <QCryptographicHash>
#include <QJsonArray>
#include <QRegularExpression>

#include <exception>

namespace {

// ----------------------------------------------------------------------------
// Allow-list / interdits d'imports (D34). Tables statiques ; la liste des
// modules custom du jeu sera fournie plus tard via le manifeste du canal
// (context["extraAllowedImports"]) — jamais de wildcard.
// ----------------------------------------------------------------------------
constexpr const char *kAllowedImports[] = {
    "QtQuick",
    "QtQuick.Shapes",
    "QtQuick.Layouts",
    "QtQuick.Controls",
    "Meow.GameApi",
};

// Rejet même en sous-import (`QtWebSockets.Foo`, `Qt.labs.platform`…) —
// vérifiés AVANT l'allow-list (QtQuick.Dialogs est sous QtQuick).
constexpr const char *kForbiddenImportPrefixes[] = {
    "QtWebSockets",
    "QtWebEngine",
    "QtMultimedia",
    "Qt.labs",
    "QtQuick.Dialogs",
    "QtQuick.LocalStorage",
    "QtNetwork",
};

// Tokens JS interdits (doc 04 §3.1) — cherchés dans le code blanchi
// (donc hors chaînes et commentaires).
struct ForbiddenJsToken
{
    const char *pattern; // regex
    const char *label;   // pour le détail remonté à l'IA
};
constexpr ForbiddenJsToken kForbiddenJsTokens[] = {
    {R"(\bXMLHttpRequest\b)", "XMLHttpRequest"},
    {R"(\bQt\s*\.\s*openUrlExternally\b)", "Qt.openUrlExternally"},
    {R"(\bQt\s*\.\s*createQmlObject\b)", "Qt.createQmlObject"},
    {R"(\bQt\s*\.\s*createComponent\b)", "Qt.createComponent"},
    {R"(\beval\s*\()", "eval("},
    {R"(\bFunction\s*\()", "Function("},
    {R"(\bimport\s*\()", "import( dynamique"},
};

ValidationFailure makeFailure(const QString &code,
                              const QString &message,
                              const QString &details,
                              bool retryable = false)
{
    ValidationFailure f;
    f.code = code;
    f.message = message;
    f.details = details;
    f.retryable = retryable;
    return f;
}

// ----------------------------------------------------------------------------
// Blanking : remplace commentaires et littéraux de chaîne par des espaces
// (les '\n' sont préservés pour garder les numéros de ligne). Les
// interpolations ${...} des template literals restent du code — un token
// interdit caché dans `${Qt.createQmlObject(...)}` doit être vu.
// Retourne false si un littéral/commentaire n'est pas terminé (échec fermé).
// ----------------------------------------------------------------------------
bool blankStringsAndComments(const QString &source,
                             QString *outBlanked,
                             QString *outErrorDetails)
{
    enum class Mode { Code, LineComment, BlockComment, StringS, StringD, Template };
    struct Frame
    {
        Mode mode;
        int interpDepth; // profondeur de {} dans une interpolation ${...}
    };

    QString blanked = source; // copie modifiée en place
    QList<Frame> stack;
    stack.append({Mode::Code, 0});

    const int n = source.size();
    for (int i = 0; i < n; ++i) {
        const QChar c = source.at(i);
        const QChar next = (i + 1 < n) ? source.at(i + 1) : QChar();
        Frame &top = stack.last();

        switch (top.mode) {
        case Mode::Code:
            if (c == QLatin1Char('/') && next == QLatin1Char('/')) {
                stack.append({Mode::LineComment, 0});
                blanked[i] = QLatin1Char(' ');
            } else if (c == QLatin1Char('/') && next == QLatin1Char('*')) {
                stack.append({Mode::BlockComment, 0});
                blanked[i] = QLatin1Char(' ');
            } else if (c == QLatin1Char('\'')) {
                stack.append({Mode::StringS, 0});
                blanked[i] = QLatin1Char(' ');
            } else if (c == QLatin1Char('"')) {
                stack.append({Mode::StringD, 0});
                blanked[i] = QLatin1Char(' ');
            } else if (c == QLatin1Char('`')) {
                stack.append({Mode::Template, 0});
                blanked[i] = QLatin1Char(' ');
            } else if (stack.size() > 1 && c == QLatin1Char('{')) {
                // Code d'interpolation : suivre la profondeur pour retrouver
                // le '}' fermant de ${...}.
                ++top.interpDepth;
            } else if (stack.size() > 1 && c == QLatin1Char('}')) {
                if (top.interpDepth == 0) {
                    // Fin de l'interpolation → retour au template literal.
                    blanked[i] = QLatin1Char(' ');
                    stack.removeLast(); // pop Code d'interpolation
                    // (le sommet redevient Template)
                } else {
                    --top.interpDepth;
                }
            }
            break;

        case Mode::LineComment:
            if (c == QLatin1Char('\n'))
                stack.removeLast();
            else
                blanked[i] = QLatin1Char(' ');
            break;

        case Mode::BlockComment:
            if (c == QLatin1Char('*') && next == QLatin1Char('/')) {
                blanked[i] = QLatin1Char(' ');
                blanked[i + 1] = QLatin1Char(' ');
                ++i; // consommer le '/'
                stack.removeLast();
            } else if (c != QLatin1Char('\n')) {
                blanked[i] = QLatin1Char(' ');
            }
            break;

        case Mode::StringS:
        case Mode::StringD: {
            const QChar quote = (top.mode == Mode::StringS) ? QLatin1Char('\'')
                                                            : QLatin1Char('"');
            if (c == QLatin1Char('\\') && i + 1 < n) {
                blanked[i] = QLatin1Char(' ');
                blanked[i + 1] = QLatin1Char(' ');
                ++i; // échappement : consommer le caractère suivant
            } else if (c == quote) {
                blanked[i] = QLatin1Char(' ');
                stack.removeLast();
            } else if (c == QLatin1Char('\n')) {
                // Chaîne simple non terminée avant fin de ligne.
                *outErrorDetails = QStringLiteral(
                    "littéral de chaîne non terminé avant la fin de ligne");
                return false;
            } else {
                blanked[i] = QLatin1Char(' ');
            }
            break;
        }

        case Mode::Template:
            if (c == QLatin1Char('\\') && i + 1 < n) {
                blanked[i] = QLatin1Char(' ');
                blanked[i + 1] = QLatin1Char(' ');
                ++i;
            } else if (c == QLatin1Char('`')) {
                blanked[i] = QLatin1Char(' ');
                stack.removeLast();
            } else if (c == QLatin1Char('$') && next == QLatin1Char('{')) {
                // Interpolation : le code interne reste visible, mais les
                // délimiteurs sont blanchis pour ne pas fausser l'équilibre.
                blanked[i] = QLatin1Char(' ');
                blanked[i + 1] = QLatin1Char(' ');
                ++i;
                stack.append({Mode::Code, 0});
            } else if (c != QLatin1Char('\n')) {
                blanked[i] = QLatin1Char(' ');
            }
            break;
        }
    }

    const Mode endMode = stack.last().mode;
    if (stack.size() > 1 && endMode != Mode::LineComment) {
        *outErrorDetails =
            (endMode == Mode::BlockComment)
                ? QStringLiteral("commentaire /* */ non terminé")
                : QStringLiteral("littéral de chaîne ou template non terminé");
        return false;
    }

    *outBlanked = blanked;
    return true;
}

// Équilibre des {} () [] sur le code blanchi.
bool checkBraceBalance(const QString &blanked, QString *outErrorDetails)
{
    QList<QChar> stack;
    for (const QChar c : blanked) {
        if (c == QLatin1Char('{') || c == QLatin1Char('(') || c == QLatin1Char('[')) {
            stack.append(c);
        } else if (c == QLatin1Char('}') || c == QLatin1Char(')') || c == QLatin1Char(']')) {
            const QChar expected = (c == QLatin1Char('}'))   ? QLatin1Char('{')
                                   : (c == QLatin1Char(')')) ? QLatin1Char('(')
                                                             : QLatin1Char('[');
            if (stack.isEmpty() || stack.last() != expected) {
                *outErrorDetails =
                    QStringLiteral("'%1' fermant sans ouvrant correspondant").arg(c);
                return false;
            }
            stack.removeLast();
        }
    }
    if (!stack.isEmpty()) {
        *outErrorDetails = QStringLiteral("'%1' ouvert mais jamais fermé")
                               .arg(stack.last());
        return false;
    }
    return true;
}

// Présence d'un objet racine QML : après les lignes import/pragma, le premier
// token doit être `Type {` (identifiant qualifié débutant par une majuscule).
bool checkRootObject(const QString &blanked, QString *outErrorDetails)
{
    static const QRegularExpression importOrPragma(
        QStringLiteral(R"(^\s*(import\b|pragma\b))"));
    static const QRegularExpression rootObject(QStringLiteral(
        R"(^\s*[A-Z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)*\s*\{)"));

    QString rest;
    const QStringList lines = blanked.split(QLatin1Char('\n'));
    qsizetype offset = 0;
    for (const QString &line : lines) {
        if (!line.trimmed().isEmpty() && !importOrPragma.match(line).hasMatch()) {
            // Première ligne de contenu : tout le reste à partir d'ici.
            rest = blanked.mid(offset);
            break;
        }
        offset += line.size() + 1; // +1 : le '\n' consommé par split()
    }

    if (rest.trimmed().isEmpty()) {
        *outErrorDetails = QStringLiteral("source vide ou sans objet racine QML");
        return false;
    }
    if (!rootObject.match(rest).hasMatch()) {
        *outErrorDetails = QStringLiteral(
            "pas d'objet racine QML (attendu : un type débutant par une "
            "majuscule suivi de '{' après les imports)");
        return false;
    }
    return true;
}

bool isForbiddenImport(const QString &module)
{
    for (const char *entry : kForbiddenImportPrefixes) {
        const QString prefix = QString::fromLatin1(entry);
        if (module == prefix || module.startsWith(prefix + QLatin1Char('.')))
            return true;
    }
    return false;
}

bool isAllowedImport(const QString &module, const QStringList &extraAllowed)
{
    // Correspondance EXACTE uniquement (échec fermé) : QtQuick n'autorise pas
    // QtQuick.Particles. Les sous-modules légitimes sont énumérés un à un.
    for (const char *entry : kAllowedImports) {
        if (module == QLatin1String(entry))
            return true;
    }
    return extraAllowed.contains(module);
}

// Extrait le littéral de chaîne dans `source` à partir de `pos` (espaces
// ignorés). Retourne une chaîne vide si l'argument n'est pas un littéral.
QString readStringLiteralAt(const QString &source, int pos)
{
    const int n = source.size();
    while (pos < n && source.at(pos).isSpace())
        ++pos;
    if (pos >= n)
        return {};
    const QChar quote = source.at(pos);
    if (quote != QLatin1Char('"') && quote != QLatin1Char('\''))
        return {}; // argument dynamique — hors de portée de l'analyse statique
    QString value;
    for (int i = pos + 1; i < n; ++i) {
        const QChar c = source.at(i);
        if (c == quote)
            return value;
        if (c == QLatin1Char('\n'))
            return {}; // non terminé — déjà attrapé par le blanking
        value.append(c);
    }
    return {};
}

} // namespace

// ----------------------------------------------------------------------------
// Sérialisation JSON (format doc 12 §4).
// ----------------------------------------------------------------------------

QJsonObject ValidationFailure::toJson() const
{
    QJsonObject o;
    o.insert(QStringLiteral("code"), code);
    o.insert(QStringLiteral("message"), message);
    o.insert(QStringLiteral("details"), details);
    o.insert(QStringLiteral("retryable"), retryable);
    return o;
}

QJsonObject ValidationResult::toJson() const
{
    QJsonObject o;
    o.insert(QStringLiteral("ok"), ok);
    QJsonArray failuresArray;
    for (const ValidationFailure &f : failures)
        failuresArray.append(f.toJson());
    o.insert(QStringLiteral("failures"), failuresArray);
    o.insert(QStringLiteral("listensTo"), QJsonArray::fromStringList(listensTo));
    o.insert(QStringLiteral("imports"), QJsonArray::fromStringList(imports));
    o.insert(QStringLiteral("sourceHash"), sourceHash);
    return o;
}

// ----------------------------------------------------------------------------
// Validation.
// ----------------------------------------------------------------------------

ValidationResult StaticValidator::validate(const QString &source,
                                           const QJsonObject &context) const
{
    ValidationResult result;
    try {
        const QByteArray utf8 = source.toUtf8();

        // Hash toujours calculé (clé du cache de verdicts, doc 12 §7).
        result.sourceHash = QString::fromLatin1(
            QCryptographicHash::hash(utf8, QCryptographicHash::Sha256).toHex());

        // --- a. source_too_large ---------------------------------------
        const qsizetype maxBytes = qsizetype(MEOW_SANDBOX_MAX_SOURCE_KB) * 1024;
        if (utf8.size() > maxBytes) {
            result.failures.append(makeFailure(
                QStringLiteral("source_too_large"),
                QStringLiteral("source trop volumineuse"),
                QStringLiteral("%1 octets > budget %2 KB (D34)")
                    .arg(utf8.size())
                    .arg(MEOW_SANDBOX_MAX_SOURCE_KB)));
        }

        // --- f. missing_module (D41) — indépendant du contenu -----------
        // Fait AVANT les contrôles de contenu pour que le retour reste
        // actionnable même si la source est aussi cassée.
        const QJsonObject modules =
            context.value(QLatin1String("modules")).toObject();
        const QJsonArray required =
            context.value(QLatin1String("requiresModules")).toArray();
        for (const QJsonValue &v : required) {
            const QString moduleId = v.toString();
            if (moduleId.isEmpty())
                continue;
            if (!modules.value(moduleId).toBool(false)) {
                result.failures.append(makeFailure(
                    QStringLiteral("missing_module"),
                    QStringLiteral("module gameplay requis inactif"),
                    QStringLiteral("le module '%1' déclaré dans requiresModules "
                                   "n'est ni actif sur la map ni activé par une "
                                   "opération du lot — l'activer via "
                                   "module_config (D41)")
                        .arg(moduleId),
                    /*retryable*/ true));
            }
        }

        // --- b. parse_failed : blanking + structure ---------------------
        QString blanked;
        QString parseDetails;
        if (!blankStringsAndComments(source, &blanked, &parseDetails)
            || !checkBraceBalance(blanked, &parseDetails)
            || !checkRootObject(blanked, &parseDetails)) {
            result.failures.append(makeFailure(
                QStringLiteral("parse_failed"),
                QStringLiteral("analyse lexicale/structurelle échouée"),
                parseDetails));
            // Échec fermé : le buffer blanchi n'est pas fiable, on n'exécute
            // pas les contrôles de contenu dessus.
            result.ok = result.failures.isEmpty();
            return result;
        }

        // --- c. import_forbidden + collecte result.imports --------------
        static const QRegularExpression importLine(
            QStringLiteral(R"(^\s*import\s)"));
        static const QRegularExpression moduleId(QStringLiteral(
            R"(^\s*import\s+([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)*))"));
        QStringList extraAllowed;
        const QJsonArray extraArray =
            context.value(QLatin1String("extraAllowedImports")).toArray();
        for (const QJsonValue &v : extraArray)
            extraAllowed.append(v.toString());

        const QStringList blankedLines = blanked.split(QLatin1Char('\n'));
        const QStringList sourceLines = source.split(QLatin1Char('\n'));
        for (int i = 0; i < blankedLines.size(); ++i) {
            if (!importLine.match(blankedLines.at(i)).hasMatch())
                continue;
            // La ligne blanchie identifie un import hors commentaire ; la
            // ligne ORIGINALE porte le texte (un import de fichier est une
            // chaîne, donc blanchie).
            const QString original = sourceLines.value(i);
            const QRegularExpressionMatch m = moduleId.match(original);
            if (!m.hasMatch()) {
                // `import "fichier.qml"` / `import "dossier"` / forme exotique
                // → interdit (doc 04 §3.1 : pas d'import de fichier arbitraire).
                result.failures.append(makeFailure(
                    QStringLiteral("import_forbidden"),
                    QStringLiteral("import de fichier ou forme non reconnue"),
                    QStringLiteral("ligne %1 : « %2 » — seuls les modules de "
                                   "l'allow-list D34 sont importables")
                        .arg(i + 1)
                        .arg(original.trimmed())));
                continue;
            }
            const QString module = m.captured(1);
            result.imports.append(module);
            if (isForbiddenImport(module)) {
                result.failures.append(makeFailure(
                    QStringLiteral("import_forbidden"),
                    QStringLiteral("module explicitement interdit"),
                    QStringLiteral("'%1' est interdit par D34 (réseau, "
                                   "fichiers, dialogues ou modules labs)")
                        .arg(module)));
            } else if (!isAllowedImport(module, extraAllowed)) {
                result.failures.append(makeFailure(
                    QStringLiteral("import_forbidden"),
                    QStringLiteral("module hors allow-list"),
                    QStringLiteral("'%1' n'est pas dans l'allow-list D34 "
                                   "(QtQuick, QtQuick.Shapes, QtQuick.Layouts, "
                                   "QtQuick.Controls, Meow.GameApi)")
                        .arg(module)));
            }
        }

        // --- d. js_forbidden --------------------------------------------
        for (const ForbiddenJsToken &token : kForbiddenJsTokens) {
            const QRegularExpression re(QString::fromLatin1(token.pattern));
            if (re.match(blanked).hasMatch()) {
                result.failures.append(makeFailure(
                    QStringLiteral("js_forbidden"),
                    QStringLiteral("construction JavaScript interdite"),
                    QStringLiteral("'%1' est interdit dans un artefact "
                                   "(doc 04 §3.1) — passer par la façade "
                                   "Meow.GameApi")
                        .arg(QLatin1String(token.label))));
            }
        }

        // --- e. timer_interval_too_low -----------------------------------
        // Uniquement les littéraux entiers dans un bloc `Timer { ... }` —
        // un interval calculé passe P0 (filet : event_flood au banc, P4).
        static const QRegularExpression timerOpen(
            QStringLiteral(R"(\bTimer\s*\{)"));
        static const QRegularExpression intervalLiteral(
            QStringLiteral(R"(\binterval\s*:\s*([0-9]+)\b)"));
        auto timerIt = timerOpen.globalMatch(blanked);
        while (timerIt.hasNext()) {
            const QRegularExpressionMatch m = timerIt.next();
            // Bloc du Timer par équilibrage d'accolades (le blanking garantit
            // qu'aucune accolade de chaîne/commentaire ne fausse le compte).
            const int openPos = int(m.capturedEnd()) - 1;
            int depth = 0;
            int closePos = -1;
            for (int i = openPos; i < blanked.size(); ++i) {
                const QChar c = blanked.at(i);
                if (c == QLatin1Char('{')) {
                    ++depth;
                } else if (c == QLatin1Char('}')) {
                    if (--depth == 0) {
                        closePos = i;
                        break;
                    }
                }
            }
            if (closePos < 0)
                continue; // déjà signalé par l'équilibre global
            const QString block = blanked.mid(openPos, closePos - openPos + 1);
            auto intervalIt = intervalLiteral.globalMatch(block);
            while (intervalIt.hasNext()) {
                const QRegularExpressionMatch im = intervalIt.next();
                bool okInt = false;
                const qlonglong value = im.captured(1).toLongLong(&okInt);
                if (okInt && value < MEOW_SANDBOX_TIMER_MIN_MS) {
                    result.failures.append(makeFailure(
                        QStringLiteral("timer_interval_too_low"),
                        QStringLiteral("Timer sous le plancher D34"),
                        QStringLiteral("interval: %1 ms < plancher %2 ms")
                            .arg(value)
                            .arg(MEOW_SANDBOX_TIMER_MIN_MS)));
                }
            }
        }

        // --- Détection listensTo (stimuli P4, doc 12 §3) ------------------
        // Couvre `events.on("type", …)` et `Meow.GameApi.events.on(…)` —
        // le préfixe éventuel n'affecte pas le motif `events.on(`.
        static const QRegularExpression eventsOn(
            QStringLiteral(R"(\bevents\s*\.\s*on\s*\()"));
        auto onIt = eventsOn.globalMatch(blanked);
        while (onIt.hasNext()) {
            const QRegularExpressionMatch m = onIt.next();
            // Le littéral est blanchi dans `blanked` : le relire dans la
            // source originale à la même position.
            const QString type = readStringLiteralAt(source, int(m.capturedEnd()));
            if (!type.isEmpty() && !result.listensTo.contains(type))
                result.listensTo.append(type);
        }

        result.ok = result.failures.isEmpty();
        return result;
    } catch (const std::exception &e) {
        // Échec fermé : jamais de pass par défaut, jamais d'exception qui fuit.
        ValidationResult failed;
        failed.sourceHash = result.sourceHash;
        failed.ok = false;
        failed.failures = {makeFailure(
            QStringLiteral("validator_internal"),
            QStringLiteral("erreur interne du validateur"),
            QString::fromUtf8(e.what()))};
        return failed;
    } catch (...) {
        ValidationResult failed;
        failed.sourceHash = result.sourceHash;
        failed.ok = false;
        failed.failures = {makeFailure(
            QStringLiteral("validator_internal"),
            QStringLiteral("erreur interne du validateur"),
            QStringLiteral("exception inconnue"))};
        return failed;
    }
}
