import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeowRules 1.0
import theme

// T4-4/T4-5 — règlement versionné et exécution host-authoritative.
Rectangle {
    id: root
    required property var host
    property var _rules: []
    property string _status: ""
    property string _lastTriggered: "—"

    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1
    implicitHeight: contentColumn.implicitHeight + Theme.spacingXXL * 2

    function _refresh() {
        root._rules = RulesEngine.rulesList()
    }

    function _addDemoRule() {
        const suffix = Date.now().toString().slice(-6)
        const rule = {
            id: "harness-tick-" + suffix,
            title: "Tick de démonstration " + suffix,
            notes: "Émet un événement borné à chaque game.tick.",
            form: "dsl",
            enabled: true,
            trigger: "game.tick",
            conditions: [],
            effects: [{ action: "event.emit",
                        args: { name: "harness.rule.fired",
                                payload: { source: "V3RulesPanel" } } }]
        }
        const ok = RulesEngine.applyRulebookOp(
                     { mode: "add_rule", rule: rule }, "harness", "ui-test")
        root._status = ok ? "Règle ajoutée : " + rule.id : RulesEngine.lastError
        root._refresh()
    }

    Component.onCompleted: {
        RulesEngine.connectSources()
        root._refresh()
    }

    Connections {
        target: RulesEngine
        function onRulebookChanged() { root._refresh() }
        function onRuleTriggered(ruleId, form, event) {
            root._lastTriggered = ruleId + " · " + form
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingM
        Text {
            text: "Moteur de règles runtime"
            color: root.host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
        }
        Text {
            text: "T4-4/T4-5 · Rulebook + RulesEngine · ordre D33"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            font.italic: true
            Layout.fillWidth: true
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "moteur"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Switch {
                objectName: "rulesEnabledSwitch"
                checked: RulesEngine.engineEnabled
                onToggled: RulesEngine.engineEnabled = checked
            }
            Text { text: "autorité hôte"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Switch {
                objectName: "rulesHostSwitch"
                checked: RulesEngine.hostAuthority
                onToggled: RulesEngine.hostAuthority = checked
            }
            Item { Layout.fillWidth: true }
        }
        GridLayout {
            columns: 4
            columnSpacing: Theme.spacingL
            rowSpacing: Theme.spacingXS
            Layout.fillWidth: true
            Text { text: "version"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: RulesEngine.version; color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }
            Text { text: "règles"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: RulesEngine.ruleCount; color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }
            Text { text: "déclenchées"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: RulesEngine.triggeredCount; color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }
            Text { text: "rejets"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                text: RulesEngine.effectRejectedCount
                color: RulesEngine.effectRejectedCount > 0 ? Theme.warning : root.host.textPrimary
                font.pixelSize: Theme.fontSizeSmall
                font.family: "Consolas"
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            Button {
                objectName: "rulesAddDemoButton"
                text: "Ajouter règle démo"
                font.pixelSize: Theme.fontSizeSmall
                onClicked: root._addDemoRule()
            }
            Button {
                objectName: "rulesTickButton"
                text: "Publier tick"
                font.pixelSize: Theme.fontSizeSmall
                enabled: RulesEngine.engineEnabled && RulesEngine.hostAuthority
                onClicked: {
                    RulesEngine.tick()
                    const drained = RulesEngine.drainNow()
                    root._status = "Tick drainé : " + drained + " événement(s)"
                }
            }
            Button {
                objectName: "rulesClearButton"
                text: "Vider"
                font.pixelSize: Theme.fontSizeSmall
                onClicked: {
                    const ok = RulesEngine.applyRulebookOp({ mode: "clear" }, "harness", "ui-clear")
                    root._status = ok ? "Règlement vidé" : RulesEngine.lastError
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(170)
            color: Theme.background
            radius: Theme.radiusM
            border.color: root.host.cardBorder
            border.width: 1
            clip: true
            ListView {
                id: rulesList
                objectName: "rulesList"
                anchors.fill: parent
                anchors.margins: Theme.spacingXS
                spacing: Theme.spacingXXS
                model: root._rules
                delegate: Rectangle {
                    required property var modelData
                    width: rulesList.width
                    height: Theme.px(42)
                    color: "transparent"
                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        text: (parent.modelData.enabled ? "● " : "○ ")
                              + (parent.modelData.title || parent.modelData.id)
                              + "  [" + parent.modelData.form + "]"
                        color: parent.modelData.enabled ? root.host.textPrimary : root.host.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        text: (parent.modelData.trigger || "sans trigger") + " · " + parent.modelData.id
                        color: root.host.textSecondary
                        font.pixelSize: Theme.fontSizeCaption
                        font.family: "Consolas"
                        elide: Text.ElideRight
                    }
                }
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            }
        }
        Text {
            text: "Dernier déclenchement : " + root._lastTriggered
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        Text {
            objectName: "rulesStatusLabel"
            text: root._status || RulesEngine.lastError
            visible: text !== ""
            color: RulesEngine.lastError ? Theme.warning : root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
}
