/*
 *      Tests unitaires — StaticValidator (préfiltre P0, V3 piste A, tâche A4)
 *
 * Compile le validateur SEUL (cpp/ai/sandbox/static_validator.cpp, QtCore
 * uniquement — garantie de linkabilité jeu/banc/tests). Le corpus d'artefacts
 * (doc/v3/12_BANC_ESSAI_R1.md §8) est lu depuis bench/test_artifacts/ via la
 * définition MEOW_TEST_ARTIFACTS_DIR (cf. tests/CMakeLists.txt).
 */
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonObject>
#include <QtTest>

#include "ai/sandbox/static_validator.h"

namespace {

QString readArtifact(const QString &fileName)
{
    const QString path =
        QDir(QStringLiteral(MEOW_TEST_ARTIFACTS_DIR)).filePath(fileName);
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(file.readAll());
}

QStringList failureCodes(const ValidationResult &r)
{
    QStringList codes;
    for (const ValidationFailure &f : r.failures)
        codes.append(f.code);
    return codes;
}

} // namespace

class TstStaticValidator : public QObject
{
    Q_OBJECT

private slots:
    // ------------------------------------------------------------------
    // Corpus doc 12 §8 — chaque artefact passe/échoue P0 comme prévu.
    // ------------------------------------------------------------------
    void corpus_data()
    {
        QTest::addColumn<QString>("fileName");
        QTest::addColumn<bool>("expectPass");
        QTest::addColumn<QString>("expectedCode");

        QTest::newRow("sain_plaque_piegee")
            << "sain_plaque_piegee.qml" << true << "";
        QTest::newRow("boucle_infinie_onload")
            << "boucle_infinie_onload.qml" << true << "";
        QTest::newRow("boucle_infinie_handler")
            << "boucle_infinie_handler.qml" << true << "";
        // Choix A4 : le plancher Timer est appliqué à P0 sur les intervalles
        // littéraux → timer_spam est rejeté sans spawner le banc.
        QTest::newRow("timer_spam")
            << "timer_spam.qml" << false << "timer_interval_too_low";
        QTest::newRow("alloc_massive")
            << "alloc_massive.qml" << true << "";
        QTest::newRow("import_interdit")
            << "import_interdit.qml" << false << "import_forbidden";
        QTest::newRow("acces_singleton")
            << "acces_singleton.qml" << true << "";
        QTest::newRow("writeset_hors_declaration")
            << "writeset_hors_declaration.qml" << true << "";
        QTest::newRow("fuite_teardown")
            << "fuite_teardown.qml" << true << "";
    }

    void corpus()
    {
        QFETCH(QString, fileName);
        QFETCH(bool, expectPass);
        QFETCH(QString, expectedCode);

        const QString source = readArtifact(fileName);
        QVERIFY2(!source.isEmpty(),
                 qPrintable(QStringLiteral("artefact introuvable : %1 (dir %2)")
                                .arg(fileName,
                                     QStringLiteral(MEOW_TEST_ARTIFACTS_DIR))));

        // Contexte : le module "stats" est actif (la plaque piégée en dépend).
        QJsonObject context;
        context.insert("modules", QJsonObject{{"stats", true}});

        StaticValidator validator;
        const ValidationResult r = validator.validate(source, context);

        if (expectPass) {
            QVERIFY2(r.ok, qPrintable(QStringLiteral("échec inattendu : %1")
                                          .arg(failureCodes(r).join(", "))));
            QVERIFY(r.failures.isEmpty());
        } else {
            QVERIFY(!r.ok);
            QVERIFY2(failureCodes(r).contains(expectedCode),
                     qPrintable(QStringLiteral("codes obtenus : %1")
                                    .arg(failureCodes(r).join(", "))));
        }
        // Le hash est calculé dans tous les cas (clé du cache de verdicts).
        QCOMPARE(r.sourceHash.size(), 64);
    }

    // ------------------------------------------------------------------
    // a. source_too_large : > MEOW_SANDBOX_MAX_SOURCE_KB (20 KB).
    // ------------------------------------------------------------------
    void sourceTooLarge()
    {
        QString source = QStringLiteral("import QtQuick\nItem {\n");
        const QString padding(MEOW_SANDBOX_MAX_SOURCE_KB * 1024,
                              QLatin1Char(' '));
        source += padding + QStringLiteral("\n}\n");

        StaticValidator validator;
        const ValidationResult r = validator.validate(source, {});
        QVERIFY(!r.ok);
        QVERIFY(failureCodes(r).contains(QStringLiteral("source_too_large")));
    }

    // ------------------------------------------------------------------
    // b. parse_failed : accolade non fermée, source vide, chaîne non
    //    terminée. Échec fermé : les contrôles de contenu sont sautés.
    // ------------------------------------------------------------------
    void parseFailedUnbalancedBrace()
    {
        StaticValidator validator;
        const ValidationResult r = validator.validate(
            QStringLiteral("import QtQuick\nItem {\n  Rectangle {\n}\n"), {});
        QVERIFY(!r.ok);
        QCOMPARE(failureCodes(r), QStringList{QStringLiteral("parse_failed")});
    }

    void parseFailedEmptySource()
    {
        StaticValidator validator;
        const ValidationResult r = validator.validate(QString(), {});
        QVERIFY(!r.ok);
        QVERIFY(failureCodes(r).contains(QStringLiteral("parse_failed")));
    }

    void parseFailedUnterminatedString()
    {
        StaticValidator validator;
        const ValidationResult r = validator.validate(
            QStringLiteral("import QtQuick\nItem { property string s: \"oops\n}\n"),
            {});
        QVERIFY(!r.ok);
        QVERIFY(failureCodes(r).contains(QStringLiteral("parse_failed")));
    }

    void parseFailedNoRootObject()
    {
        StaticValidator validator;
        const ValidationResult r = validator.validate(
            QStringLiteral("import QtQuick\nfunction hack() { return 1 }\n"), {});
        QVERIFY(!r.ok);
        QVERIFY(failureCodes(r).contains(QStringLiteral("parse_failed")));
    }

    // ------------------------------------------------------------------
    // c. import_forbidden : préfixe Qt.labs, sous-import d'un interdit,
    //    import de fichier, module hors allow-list, extension par contexte.
    // ------------------------------------------------------------------
    void importForbiddenQtLabs()
    {
        StaticValidator validator;
        const ValidationResult r = validator.validate(
            QStringLiteral("import QtQuick\nimport Qt.labs.platform\nItem {}\n"),
            {});
        QVERIFY(!r.ok);
        QVERIFY(failureCodes(r).contains(QStringLiteral("import_forbidden")));
        // La liste des imports est tout de même collectée.
        QVERIFY(r.imports.contains(QStringLiteral("Qt.labs.platform")));
    }

    void importForbiddenSubmoduleOfForbidden()
    {
        StaticValidator validator;
        const ValidationResult r = validator.validate(
            QStringLiteral("import QtWebEngine.Core\nItem {}\n"), {});
        QVERIFY(!r.ok);
        QVERIFY(failureCodes(r).contains(QStringLiteral("import_forbidden")));
    }

    void importForbiddenFileImport()
    {
        StaticValidator validator;
        const ValidationResult r = validator.validate(
            QStringLiteral("import QtQuick\nimport \"exploit.js\" as X\nItem {}\n"),
            {});
        QVERIFY(!r.ok);
        QVERIFY(failureCodes(r).contains(QStringLiteral("import_forbidden")));
    }

    void importOutsideAllowList()
    {
        StaticValidator validator;
        // QtQuick.Particles n'est ni interdit explicitement ni dans
        // l'allow-list → rejet (correspondance exacte, échec fermé).
        const ValidationResult r = validator.validate(
            QStringLiteral("import QtQuick.Particles\nItem {}\n"), {});
        QVERIFY(!r.ok);
        QVERIFY(failureCodes(r).contains(QStringLiteral("import_forbidden")));
    }

    void importExtensibleViaContext()
    {
        StaticValidator validator;
        const QString source =
            QStringLiteral("import QtQuick\nimport Meow.Snapables\nItem {}\n");
        // Sans extension : rejeté.
        QVERIFY(!validator.validate(source, {}).ok);
        // Avec le module custom énuméré par le manifeste (D34) : accepté.
        QJsonObject context;
        context.insert("extraAllowedImports",
                       QJsonArray{QStringLiteral("Meow.Snapables")});
        const ValidationResult r = validator.validate(source, context);
        QVERIFY2(r.ok, qPrintable(failureCodes(r).join(", ")));
    }

    void importCommentedOutIsIgnored()
    {
        StaticValidator validator;
        const ValidationResult r = validator.validate(
            QStringLiteral("import QtQuick\n// import QtWebSockets\nItem {}\n"),
            {});
        QVERIFY2(r.ok, qPrintable(failureCodes(r).join(", ")));
        QCOMPARE(r.imports, QStringList{QStringLiteral("QtQuick")});
    }

    // ------------------------------------------------------------------
    // d. js_forbidden : tokens hors chaînes/commentaires uniquement.
    // ------------------------------------------------------------------
    void jsForbidden_data()
    {
        QTest::addColumn<QString>("snippet");
        QTest::newRow("eval") << "eval(\"1+1\")";
        QTest::newRow("Function") << "const f = Function(\"return 1\")";
        QTest::newRow("newFunction") << "const f = new Function(\"return 1\")";
        QTest::newRow("createQmlObject")
            << "Qt.createQmlObject(\"import QtQuick; Item{}\", root)";
        QTest::newRow("createComponent") << "Qt.createComponent(\"a.qml\")";
        QTest::newRow("openUrlExternally")
            << "Qt.openUrlExternally(\"https://example.invalid\")";
        QTest::newRow("XMLHttpRequest") << "const x = new XMLHttpRequest()";
        QTest::newRow("dynamicImport") << "import(\"module\")";
    }

    void jsForbidden()
    {
        QFETCH(QString, snippet);
        StaticValidator validator;
        const QString source =
            QStringLiteral("import QtQuick\nItem {\n"
                           "  Component.onCompleted: { %1 }\n}\n")
                .arg(snippet);
        const ValidationResult r = validator.validate(source, {});
        QVERIFY(!r.ok);
        QVERIFY2(failureCodes(r).contains(QStringLiteral("js_forbidden")),
                 qPrintable(failureCodes(r).join(", ")));
    }

    void jsForbiddenTokenInStringOrCommentPasses()
    {
        StaticValidator validator;
        const ValidationResult r = validator.validate(
            QStringLiteral(
                "import QtQuick\nItem {\n"
                "  // eval( et XMLHttpRequest ici ne comptent pas\n"
                "  property string doc: \"Qt.createQmlObject est interdit\"\n"
                "}\n"),
            {});
        QVERIFY2(r.ok, qPrintable(failureCodes(r).join(", ")));
    }

    void jsForbiddenTokenInTemplateInterpolationCaught()
    {
        StaticValidator validator;
        // Le code des interpolations ${...} reste analysé (échec fermé).
        const ValidationResult r = validator.validate(
            QStringLiteral("import QtQuick\nItem {\n"
                           "  Component.onCompleted: console.log(`x=${eval(\"1\")}`)\n"
                           "}\n"),
            {});
        QVERIFY(!r.ok);
        QVERIFY(failureCodes(r).contains(QStringLiteral("js_forbidden")));
    }

    // ------------------------------------------------------------------
    // e. timer_interval_too_low : littéral sous le plancher ; un interval
    //    calculé passe P0 (limitation documentée, filet = P4 event_flood).
    // ------------------------------------------------------------------
    void timerIntervalLiteralOk()
    {
        StaticValidator validator;
        const ValidationResult r = validator.validate(
            QStringLiteral("import QtQuick\nItem { Timer { interval: 100 } }\n"),
            {});
        QVERIFY2(r.ok, qPrintable(failureCodes(r).join(", ")));
    }

    void timerIntervalExpressionWithLeadingLiteralRejected()
    {
        StaticValidator validator;
        // Le motif attrape le littéral en tête d'expression (`1 * vitesse`)
        // → rejet. Durcissement volontaire (échec fermé) : un plancher
        // exprimé en multiple d'un littéral < 100 reste suspect.
        const ValidationResult r = validator.validate(
            QStringLiteral("import QtQuick\n"
                           "Item { Timer { interval: 1 * vitesse } }\n"),
            {});
        QVERIFY(!r.ok);
        QVERIFY(failureCodes(r).contains(
            QStringLiteral("timer_interval_too_low")));
    }

    void timerIntervalBindingEscapesP0()
    {
        StaticValidator validator;
        // Binding pur (pas de littéral en tête) : passe P0, attrapé au banc.
        const ValidationResult r = validator.validate(
            QStringLiteral("import QtQuick\n"
                           "Item { Timer { interval: root.cadence } }\n"),
            {});
        QVERIFY2(r.ok, qPrintable(failureCodes(r).join(", ")));
    }

    // ------------------------------------------------------------------
    // f. missing_module (D41) : retryable, un fail par module manquant.
    // ------------------------------------------------------------------
    void missingModuleRetryable()
    {
        StaticValidator validator;
        const QString source = readArtifact(QStringLiteral("sain_plaque_piegee.qml"));
        QVERIFY(!source.isEmpty());

        QJsonObject context;
        context.insert("requiresModules", QJsonArray{QStringLiteral("stats")});
        context.insert("modules", QJsonObject{{"stats", false}});

        const ValidationResult r = validator.validate(source, context);
        QVERIFY(!r.ok);
        QCOMPARE(failureCodes(r), QStringList{QStringLiteral("missing_module")});
        QVERIFY(r.failures.first().retryable);

        // Module actif → pass.
        context.insert("modules", QJsonObject{{"stats", true}});
        QVERIFY(validator.validate(source, context).ok);
    }

    // ------------------------------------------------------------------
    // Détection listensTo (stimuli P4, doc 12 §3).
    // ------------------------------------------------------------------
    void listensToDetected()
    {
        StaticValidator validator;
        const QString source = readArtifact(QStringLiteral("sain_plaque_piegee.qml"));
        QVERIFY(!source.isEmpty());
        const ValidationResult r = validator.validate(source, {});
        QCOMPARE(r.listensTo, QStringList{QStringLiteral("zoneEntered")});
    }

    void listensToWithFacadePrefixAndDedup()
    {
        StaticValidator validator;
        const ValidationResult r = validator.validate(
            QStringLiteral(
                "import QtQuick\nimport Meow.GameApi\nItem {\n"
                "  Component.onCompleted: {\n"
                "    Meow.GameApi.events.on(\"memoryChanged\", function () {})\n"
                "    events.on('zoneExited', function () {})\n"
                "    events.on(\"zoneExited\", function () {})\n"
                "  }\n}\n"),
            {});
        QVERIFY2(r.ok, qPrintable(failureCodes(r).join(", ")));
        QCOMPARE(r.listensTo,
                 (QStringList{QStringLiteral("memoryChanged"),
                              QStringLiteral("zoneExited")}));
    }

    // ------------------------------------------------------------------
    // Hash SHA-256 : stable, calculé même en échec, sensible au contenu.
    // ------------------------------------------------------------------
    void hashStableAndAlwaysComputed()
    {
        StaticValidator validator;
        const QString source =
            QStringLiteral("import QtQuick\nItem { }\n");

        const ValidationResult r1 = validator.validate(source, {});
        const ValidationResult r2 = validator.validate(source, {});
        QCOMPARE(r1.sourceHash, r2.sourceHash);

        const QString expected = QString::fromLatin1(
            QCryptographicHash::hash(source.toUtf8(),
                                     QCryptographicHash::Sha256)
                .toHex());
        QCOMPARE(r1.sourceHash, expected);

        // Différent pour une source différente, et présent même en échec.
        const ValidationResult r3 =
            validator.validate(QStringLiteral("import QtWebSockets\nItem{}\n"), {});
        QVERIFY(!r3.ok);
        QCOMPARE(r3.sourceHash.size(), 64);
        QVERIFY(r3.sourceHash != r1.sourceHash);
    }
};

QTEST_GUILESS_MAIN(TstStaticValidator)
#include "tst_static_validator.moc"
