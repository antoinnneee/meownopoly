/*
 *      V3 / Phase 2 — S-7 · Harness UI des scénarios S1/S2/S3 (doc v3 11)
 *
 * Page de dev qui pilote SliceScenarioRunner (rôle proposant + arbitre + banc
 * simulé) et affiche le rapport d'instrumentation (critères doc 11 §5 + Q-J04).
 *
 * PRÉREQUIS DE CÂBLAGE : le module QML `MeowSlice` (SliceScenarioRunner,
 * SliceInstrumentation) doit être enregistré dans `qmlapp.cpp` via
 * `SliceScenarioRunner::registerQml()` + `SliceInstrumentation::registerQml()`.
 * Ce câblage est HORS périmètre fichier de S-7 (qmlapp.cpp = [pat]) — voir les
 * blockers de la tâche. Tant qu'il n'est pas fait, cette page n'est pas
 * instanciable ; le harness reste exécutable côté C++ via `instance()`.
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeowSlice 1.0

Item {
    id: root

    property color bg: "#12141a"
    property color card: "#1c1f28"
    property color border: "#2b2f3a"
    property color text: "#e6e8ee"
    property color muted: "#9aa0ad"
    property color okColor: "#4caf7d"
    property color koColor: "#e2555a"

    Rectangle { anchors.fill: parent; color: root.bg }

    function fmt(v) { return JSON.stringify(v, null, 2) }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
            text: "Vertical slice V3 — scénarios S1/S2/S3 (doc 11 §5)"
            color: root.text
            font.pixelSize: 20
            font.bold: true
        }

        RowLayout {
            spacing: 8
            Repeater {
                model: [
                    { label: "Run S1", fn: "runS1" },
                    { label: "Run S2", fn: "runS2" },
                    { label: "Run S3", fn: "runS3" },
                    { label: "Run tout + rapport", fn: "runAll" }
                ]
                delegate: Button {
                    required property var modelData
                    text: modelData.label
                    onClicked: {
                        const res = SliceScenarioRunner[modelData.fn]()
                        resultView.text = root.fmt(res)
                        reportView.text = root.fmt(SliceInstrumentation.report())
                    }
                }
            }
        }

        RowLayout {
            spacing: 10
            Rectangle {
                width: 14; height: 14; radius: 7
                color: SliceInstrumentation.overallPass ? root.okColor : root.koColor
            }
            Text {
                color: root.text
                text: "Verdict global : " + (SliceInstrumentation.overallPass ? "PASS" : "à jouer / KO")
                       + "  ·  invocations=" + SliceInstrumentation.invocationCount
                       + "  ·  gel max=" + SliceInstrumentation.maxGuiStallMs.toFixed(3) + " ms"
                       + "  ·  hors-canal=" + SliceInstrumentation.offChannelAccessCount
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // Résultat du dernier scénario
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.card
                radius: 8
                border.color: root.border
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    Text { text: "Dernier scénario"; color: root.muted; font.bold: true }
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        TextArea {
                            id: resultView
                            readOnly: true
                            wrapMode: TextEdit.Wrap
                            color: root.text
                            font.family: "monospace"
                            font.pixelSize: 12
                            text: "— clique un scénario —"
                        }
                    }
                }
            }

            // Rapport d'instrumentation
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.card
                radius: 8
                border.color: root.border
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    Text { text: "Rapport (critères §5 + Q-J04)"; color: root.muted; font.bold: true }
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        TextArea {
                            id: reportView
                            readOnly: true
                            wrapMode: TextEdit.Wrap
                            color: root.text
                            font.family: "monospace"
                            font.pixelSize: 12
                            text: "— clique « Run tout » —"
                        }
                    }
                }
            }
        }
    }
}
