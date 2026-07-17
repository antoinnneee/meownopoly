// ============================================================================
// static_validator — implémentation du préfiltre statique P0 (doc 12 §3, D34/D41)
// ============================================================================

#include "static_validator.h"

#include <QJsonArray>
#include <QRegularExpression>

namespace meow::sandbox {

namespace {

inline QString code(const char *c) { return QString::fromLatin1(c); }

// ─── Interdits statiques (D34 §3.1) ─────────────────────────────────────────
// Jetons dont la simple présence (hors chaîne/commentaire) disqualifie l'artefact.
// Recherchés avec des bornes de mot pour ne pas matcher un sous-identifiant
// (ex. `myCreateComponentHelper` ne déclenche pas `createComponent`).
struct ForbiddenToken { const char *token; const char *reason; };
const ForbiddenToken kForbidden[] = {
    { "XMLHttpRequest",       "accès réseau (XMLHttpRequest) interdit" },
    { "Qt.openUrlExternally", "ouverture d'URL externe interdite" },
    { "Qt.createQmlObject",   "instanciation QML imbriquée non contrôlée interdite" },
    { "Qt.createComponent",   "chargement de composant non contrôlé interdit" },
    { "Qt.exit",              "contrôle du cycle de vie du process interdit (Qt.exit)" },
    { "Qt.quit",              "contrôle du cycle de vie du process interdit (Qt.quit)" },
    { "Qt.application",       "accès à l'objet application interdit" },
    { "FileDialog",           "accès au système de fichiers interdit (FileDialog)" },
    { "FolderDialog",         "accès au système de fichiers interdit (FolderDialog)" },
    { "LocalStorage",         "stockage local interdit (QtQuick.LocalStorage)" },
    { "openDatabaseSync",     "stockage local interdit (openDatabaseSync)" },
    { "WebSocket",            "accès réseau interdit (WebSocket)" },
    { "Process",              "lancement de process interdit" },
};

// Vrai si `full` contient `needle` délimité par des bornes de non-identifiant.
bool containsToken(const QString &full, const QString &needle)
{
    const QRegularExpression re(
        QStringLiteral("(?<![A-Za-z0-9_])%1(?![A-Za-z0-9_])")
            .arg(QRegularExpression::escape(needle)));
    return re.match(full).hasMatch();
}

} // namespace

// ─── toJson ─────────────────────────────────────────────────────────────────
QJsonObject StaticFinding::toJson() const
{
    QJsonObject o;
    o.insert(QStringLiteral("code"), code);
    o.insert(QStringLiteral("details"), details);
    o.insert(QStringLiteral("retryable"), retryable);
    return o;
}

QJsonObject StaticValidationResult::toJson() const
{
    QJsonObject o;
    o.insert(QStringLiteral("passed"), passed());
    QJsonArray fs;
    for (const StaticFinding &f : findings)
        fs.append(f.toJson());
    o.insert(QStringLiteral("findings"), fs);
    QJsonArray imp;
    for (const QString &m : imports)
        imp.append(m);
    o.insert(QStringLiteral("imports"), imp);
    return o;
}

// ─── Allow-list de base (D34) ───────────────────────────────────────────────
QStringList StaticValidator::baseAllowedImports()
{
    return {
        QStringLiteral("QtQuick"),
        QStringLiteral("QtQuick.Shapes"),
        QStringLiteral("QtQuick.Layouts"),
        QStringLiteral("QtQuick.Controls"),
        QStringLiteral("Meow.GameApi"),
    };
}

// ─── Nettoyage lexical (commentaires + littéraux) ───────────────────────────
// Machine à états volontairement simple : elle retire commentaires `//` et
// `/* */` et, sur demande, les chaînes `"…"`, `'…'`, `` `…` ``. Elle NE tente
// PAS de distinguer un littéral d'expression régulière (`/…/`) d'une division :
// heuristique fragile, et une regex ne contient pas d'identifiant interdit. Le
// résidu éventuel est inoffensif pour les contrôles de jetons/imports.
QString StaticValidator::sanitize(const QString &src, bool removeStrings,
                                  bool *wellTerminated)
{
    enum State { Normal, Line, Block, DQ, SQ, TL };
    State st = Normal;
    bool esc = false;
    QString out;
    out.reserve(src.size());

    const int n = src.size();
    for (int i = 0; i < n; ++i) {
        const QChar c = src.at(i);
        const QChar nx = (i + 1 < n) ? src.at(i + 1) : QChar();
        switch (st) {
        case Normal:
            if (c == QLatin1Char('/') && nx == QLatin1Char('/')) { st = Line; ++i; }
            else if (c == QLatin1Char('/') && nx == QLatin1Char('*')) { st = Block; ++i; }
            else if (c == QLatin1Char('"'))  { st = DQ; esc = false; if (!removeStrings) out += c; }
            else if (c == QLatin1Char('\'')) { st = SQ; esc = false; if (!removeStrings) out += c; }
            else if (c == QLatin1Char('`'))  { st = TL; esc = false; if (!removeStrings) out += c; }
            else out += c;
            break;
        case Line: // // … jusqu'au saut de ligne
            if (c == QLatin1Char('\n')) { st = Normal; out += c; }
            break;
        case Block: // /* … */
            if (c == QLatin1Char('*') && nx == QLatin1Char('/')) { st = Normal; ++i; }
            break;
        case DQ:
        case SQ: {
            const QChar quote = (st == DQ) ? QLatin1Char('"') : QLatin1Char('\'');
            if (esc) { esc = false; if (!removeStrings) out += c; }
            else if (c == QLatin1Char('\\')) { esc = true; if (!removeStrings) out += c; }
            else if (c == quote) { st = Normal; if (!removeStrings) out += c; }
            else if (c == QLatin1Char('\n')) {
                // Chaîne non fermée sur la ligne : on referme par tolérance
                // (une chaîne JS/QML ne s'étend pas sur plusieurs lignes) et on
                // préserve la structure des lignes.
                st = Normal; out += c;
            }
            else if (!removeStrings) out += c;
            break;
        }
        case TL: // template literal `…` (peut couvrir plusieurs lignes)
            if (esc) { esc = false; if (!removeStrings) out += c; }
            else if (c == QLatin1Char('\\')) { esc = true; if (!removeStrings) out += c; }
            else if (c == QLatin1Char('`')) { st = Normal; if (!removeStrings) out += c; }
            else if (!removeStrings) out += c;
            break;
        }
    }

    if (wellTerminated)
        *wellTerminated = (st == Normal || st == Line);
    return out;
}

// ─── Extraction des imports ─────────────────────────────────────────────────
QStringList StaticValidator::extractImports(const QString &sourceNoComments)
{
    QStringList out;
    const QStringList lines = sourceNoComments.split(QLatin1Char('\n'));
    for (const QString &raw : lines) {
        const QString line = raw.trimmed();
        if (!line.startsWith(QStringLiteral("import")))
            continue;
        // Frontière : « import » suivi d'un blanc (évite un identifiant
        // `importantFlag`).
        if (line.size() <= 6 || !line.at(6).isSpace())
            continue;
        const QString spec = line.mid(6).trimmed();
        if (spec.isEmpty())
            continue;
        // Import de fichier/JS entre guillemets : renvoyé avec son guillemet
        // ouvrant pour signalement (D34 : pas d'import "…js" arbitraire).
        if (spec.startsWith(QLatin1Char('"')) || spec.startsWith(QLatin1Char('\''))) {
            out << spec.left(1) + spec.mid(1).section(spec.at(0), 0, 0);
            continue;
        }
        // Premier jeton = identifiant de module (le reste = version, `as Alias`).
        const QString moduleId = spec.section(QRegularExpression(QStringLiteral("\\s+")), 0, 0);
        if (!moduleId.isEmpty())
            out << moduleId;
    }
    return out;
}

// ─── Validation ─────────────────────────────────────────────────────────────
StaticValidationResult StaticValidator::validate(const StaticValidationInput &in)
{
    StaticValidationResult res;
    auto add = [&res](const char *c, const QString &details, bool retryable = true) {
        StaticFinding f;
        f.code = code(c);
        f.details = details;
        f.retryable = retryable;
        res.findings.append(f);
    };

    // 1. Taille (D34 : ≤ 20 KO). Mesure en octets UTF-8 (cohérent avec le
    //    plafond réseau `maxArtifactSourceBytes` du manifeste).
    const int bytes = in.source.toUtf8().size();
    if (bytes > MEOW_STATIC_MAX_SOURCE_BYTES) {
        add(failure::kSourceTooLarge,
            QStringLiteral("source de %1 octets > plafond %2 (D34)")
                .arg(bytes).arg(MEOW_STATIC_MAX_SOURCE_BYTES));
    }

    // 2. Nettoyage lexical + détection de littéral/commentaire non terminé.
    bool wellTerminated = true;
    const QString cleaned = sanitize(in.source, /*removeStrings=*/true, &wellTerminated);
    if (!wellTerminated) {
        add(failure::kQmlParseError,
            QStringLiteral("littéral de chaîne ou commentaire bloc non terminé"));
    }
    if (cleaned.trimmed().isEmpty() && wellTerminated) {
        add(failure::kQmlParseError,
            QStringLiteral("source vide ou sans contenu exploitable"));
    }

    // 3. Allow-list d'imports (D34). Base + modules custom du manifeste.
    QSet<QString> allowed;
    for (const QString &m : baseAllowedImports())
        allowed.insert(m);
    for (const QString &m : in.extraAllowedImports)
        allowed.insert(m);

    const QString noComments = sanitize(in.source, /*removeStrings=*/false);
    const QStringList imports = extractImports(noComments);
    res.imports = imports;
    for (const QString &imp : imports) {
        if (imp.startsWith(QLatin1Char('"')) || imp.startsWith(QLatin1Char('\''))) {
            add(failure::kImportForbidden,
                QStringLiteral("import de fichier/JS arbitraire interdit : %1").arg(imp));
            continue;
        }
        if (!allowed.contains(imp)) {
            add(failure::kImportForbidden,
                QStringLiteral("module « %1 » hors allow-list (autorisés : %2)")
                    .arg(imp, QStringList(allowed.values()).join(QStringLiteral(", "))));
        }
    }

    // 4. Interdits statiques (D34 §3.1) sur le texte nettoyé (hors chaînes).
    for (const ForbiddenToken &ft : kForbidden) {
        const QString tok = QString::fromLatin1(ft.token);
        if (containsToken(cleaned, tok)) {
            add(failure::kForbiddenConstruct,
                QStringLiteral("%1").arg(QString::fromLatin1(ft.reason)));
        }
    }

    // 5. Dépendances de modules (D41). Un `requiresModules` doit être actif sur
    //    la map OU activé par une opération du même lot. Jamais d'activation
    //    implicite.
    for (const QString &mod : in.requiresModules) {
        if (mod.isEmpty())
            continue;
        if (in.activeModules.contains(mod) || in.batchActivatedModules.contains(mod))
            continue;
        add(failure::kMissingModule,
            QStringLiteral("le module « %1 » requis par l'artefact n'est ni actif "
                           "sur la map ni activé par une opération du lot").arg(mod));
    }

    return res;
}

} // namespace meow::sandbox
