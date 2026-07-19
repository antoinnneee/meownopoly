import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeowSlice 1.0
import theme
import ui_item

// Harness V3 — banc d'essai R1 + instrumentation de la slice (A7/A8, doc 11-12).
//
// Édition d'une source QML d'artefact + validation au banc RÉEL hors-process
// (P0 statique puis process meow_testbench via le pool, cf.
// SliceScenarioRunner.validateArtifact). Affiche le verdict complet (pass/fail,
// failures + codes, métriques) et déroule les scénarios S1/S2/S3.
Rectangle {
    id: root
    required property var host

    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1
    implicitHeight: content.implicitHeight + Theme.spacingXXL * 2

    // Artefact SAIN de référence du corpus (test_artifacts/sain_plaque_piegee.qml).
    readonly property string _sampleArtifact:
`// « Plaque piégée » — artefact SAIN de référence (doc v3 11, critère R1 n°5).
// Attendu : pass, toutes les métriques dans les budgets D34.
import QtQuick

Item {
    id: root

    Component.onCompleted: {
        GameApi.events.on("zoneEntered", function(evt) {
            const actor = evt && evt.actorId ? evt.actorId : "inconnu";
            let score = GameApi.memory.get("score");
            if (typeof score !== "number")
                score = 0;
            score += 10;
            GameApi.stats.addModifier(actor, "speed", -0.2);
            GameApi.memory.set("score", score);
        });
    }
}
`

    property var _verdict: null           // dernier verdict (objet JS) ou null
    property string _pendingJobId: ""     // job en attente de verdict
    property bool _running: false
    property var _scenarios: []           // résultats S1/S2/S3

    function _metricsList(metrics) {
        const out = []
        if (metrics) {
            for (const k in metrics)
                out.push({ "k": k, "v": "" + metrics[k] })
        }
        return out
    }

    Connections {
        target: SliceScenarioRunner
        function onArtifactVerdictReady(jobId, verdict) {
            if (jobId !== root._pendingJobId)
                return
            root._verdict = verdict
            root._running = false
            root._pendingJobId = ""
        }
    }

    component FieldLabel: Text {
        color: root.host.textSecondary
        font.pixelSize: Theme.fontSizeSmall
    }
    component StyledButton: MeowButton {
        property color tint: root.host.accent
        baseColor: tint
        implicitHeight: Theme.px(28)
        padding: Theme.spacingM
        fontSize: Theme.fontSizeSmall
        hoverZoom: false
        glossy: false
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingM

        Text {
            text: "Banc d'essai / instrumentation"
            color: root.host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
        }
        Text {
            text: "MeowSlice 1.0 · validation d'artefact (P0 + banc hors-process) + scénarios S1/S2/S3"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            font.italic: true
            Layout.fillWidth: true
        }

        // — Éditeur de source d'artefact —
        FieldLabel { text: "Source de l'artefact QML" }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(180)
            radius: Theme.radiusS
            color: Theme.background
            border.color: root.host.cardBorder
            border.width: 1
            ScrollView {
                anchors.fill: parent
                anchors.margins: Theme.spacingXS
                clip: true
                MeowTextArea {
                    id: sourceArea
                    objectName: "benchSourceArea"
                    text: root._sampleArtifact
                    color: root.host.textPrimary
                    font.pixelSize: Theme.fontSizeCaption
                    font.family: "Consolas"
                    wrapMode: TextArea.NoWrap
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            StyledButton {
                objectName: "benchValidateBtn"
                text: root._running ? "Validation…" : "Valider au banc"
                tint: Theme.success
                enabled: !root._running
                onClicked: {
                    root._verdict = null
                    root._running = true
                    root._pendingJobId = SliceScenarioRunner.validateArtifact(sourceArea.text)
                }
            }
            StyledButton {
                objectName: "benchResetSourceBtn"
                text: "Réinitialiser source"
                tint: Theme.surfaceAlt
                onClicked: sourceArea.text = root._sampleArtifact
            }
            Item { Layout.fillWidth: true }
        }

        // — Verdict —
        Rectangle {
            Layout.fillWidth: true
            visible: root._verdict !== null
            Layout.preferredHeight: verdictCol.implicitHeight + Theme.spacingM * 2
            radius: Theme.radiusS
            readonly property bool _pass: root._verdict && root._verdict.verdict === "pass"
            color: Qt.rgba(_pass ? Theme.success.r : Theme.danger.r,
                           _pass ? Theme.success.g : Theme.danger.g,
                           _pass ? Theme.success.b : Theme.danger.b, 0.12)
            border.color: _pass ? Theme.success : Theme.danger
            border.width: 1

            ColumnLayout {
                id: verdictCol
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingXS

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM
                    Text {
                        objectName: "benchVerdictBadge"
                        text: root._verdict ? (root._verdict.verdict === "pass" ? "PASS" : "FAIL") : ""
                        color: (root._verdict && root._verdict.verdict === "pass") ? Theme.success : Theme.danger
                        font.pixelSize: Theme.fontSizeMedium; font.bold: true
                    }
                    Text {
                        text: root._verdict ? ("stage: " + (root._verdict.stage || "?")) : ""
                        color: root.host.textSecondary
                        font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas"
                    }
                    Text {
                        visible: root._verdict && root._verdict.durationMs !== undefined
                        text: root._verdict ? (root._verdict.durationMs + " ms") : ""
                        color: root.host.textSecondary
                        font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas"
                    }
                    Item { Layout.fillWidth: true }
                }

                // Failures
                Repeater {
                    model: (root._verdict && root._verdict.failures) ? root._verdict.failures : []
                    delegate: Text {
                        required property var modelData
                        Layout.fillWidth: true
                        text: "✗ " + (modelData.code || "?")
                              + (modelData.phase ? " [" + modelData.phase + "]" : "")
                              + (modelData.details ? " — " + modelData.details : "")
                        color: Theme.dangerSoft
                        font.pixelSize: Theme.fontSizeCaption; font.family: "Consolas"
                        wrapMode: Text.WordWrap
                    }
                }

                // Métriques (tickUs*, peakMemMB, loadMs, objectCount…)
                Repeater {
                    model: root._metricsList(root._verdict ? root._verdict.metrics : null)
                    delegate: Text {
                        required property var modelData
                        text: "  " + modelData.k + " = " + modelData.v
                        color: root.host.textSecondary
                        font.pixelSize: Theme.fontSizeCaption; font.family: "Consolas"
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.host.cardBorder }

        // — Scénarios S1/S2/S3 —
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            StyledButton {
                objectName: "benchRunS1Btn"; text: "S1"
                onClicked: root._scenarios = [SliceScenarioRunner.runS1()]
            }
            StyledButton {
                objectName: "benchRunS2Btn"; text: "S2"
                onClicked: root._scenarios = [SliceScenarioRunner.runS2()]
            }
            StyledButton {
                objectName: "benchRunS3Btn"; text: "S3"
                onClicked: root._scenarios = [SliceScenarioRunner.runS3()]
            }
            StyledButton {
                objectName: "benchRunAllBtn"; text: "Lancer S1/S2/S3"
                tint: root.host.accent
                onClicked: {
                    const r = SliceScenarioRunner.runAll()
                    root._scenarios = r.scenarios
                }
            }
            Item { Layout.fillWidth: true }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXXS
            Repeater {
                model: root._scenarios
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.spacingM
                    Text {
                        text: modelData.ok ? "✓" : "✗"
                        color: modelData.ok ? Theme.success : Theme.danger
                        font.pixelSize: Theme.fontSizeSmall; font.bold: true
                    }
                    Text {
                        text: "" + modelData.scenario
                        color: root.host.textPrimary
                        font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas"
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.note ? modelData.note : ""
                        color: root.host.textSecondary
                        font.pixelSize: Theme.fontSizeCaption
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.host.cardBorder }

        // — Instrumentation live —
        GridLayout {
            columns: 4
            columnSpacing: Theme.spacingXL
            rowSpacing: Theme.spacingXS
            Layout.fillWidth: true

            FieldLabel { text: "invocationCount" }
            Text {
                text: "" + SliceInstrumentation.invocationCount
                color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas"
            }
            FieldLabel { text: "maxGuiStallMs" }
            Text {
                text: "" + SliceInstrumentation.maxGuiStallMs
                color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas"
            }
            FieldLabel { text: "offChannelAccess" }
            Text {
                text: "" + SliceInstrumentation.offChannelAccessCount
                color: SliceInstrumentation.offChannelAccessCount > 0 ? Theme.danger : root.host.textPrimary
                font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas"
            }
            FieldLabel { text: "overallPass" }
            Text {
                objectName: "benchOverallPass"
                text: "" + SliceInstrumentation.overallPass
                color: SliceInstrumentation.overallPass ? Theme.success : Theme.warning
                font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas"; font.bold: true
            }
        }
    }
}
