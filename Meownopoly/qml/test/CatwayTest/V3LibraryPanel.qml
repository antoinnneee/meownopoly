import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AssetManager 1.0
import LauncherManager 1.0
import theme
import ui_item

// T5-1 / M11 — package versionné de la bibliothèque officielle GLB.
Rectangle {
    id: root
    required property var host
    property var _models: []
    property string _inspection: ""
    property string _validation: ""

    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1
    implicitHeight: contentColumn.implicitHeight + Theme.spacingXXL * 2

    function _refresh() {
        root._models = AssetManager.getAvailableModels()
        if (root._models.length > 0) {
            modelCombo.currentIndex = 0
            root._inspect(root._models[0])
        } else {
            root._inspection = "Aucun modèle installé dans AppDataLocation/models."
        }
    }

    function _inspect(name) {
        if (!name) return
        const report = {
            model: name,
            package: AssetManager.readPackageManifest(name),
            installation: LauncherManager.installedPackageInfo(name),
            integrity: AssetManager.verifyPackageIntegrity(name),
            resolution: AssetManager.resolveModelReference(name, "", "")
        }
        root._inspection = JSON.stringify(report, null, 2)
    }

    function _validate() {
        const result = AssetManager.validatePackageManifest(manifestArea.text)
        root._validation = JSON.stringify(result, null, 2)
    }

    Component.onCompleted: root._refresh()

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingM
        Text {
            text: "Bibliothèque officielle GLB"
            color: root.host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
        }
        Text {
            text: "T5-1 · manifeste, versions atomiques, hash et budgets"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            font.italic: true
            Layout.fillWidth: true
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            MeowComboBox {
                id: modelCombo
                objectName: "libraryModelCombo"
                model: root._models
                Layout.fillWidth: true
                font.pixelSize: Theme.fontSizeSmall
                onCurrentTextChanged: root._inspect(currentText)
            }
            MeowButton {
                objectName: "libraryRefreshButton"
                text: "Scanner"
                font.pixelSize: Theme.fontSizeSmall
                onClicked: root._refresh()
            }
        }
        MeowTextArea {
            objectName: "libraryInspectionArea"
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(190)
            readOnly: true
            text: root._inspection
            wrapMode: TextEdit.NoWrap
            font.family: "Consolas"
            font.pixelSize: Theme.fontSizeCaption
            color: root.host.textPrimary
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.host.cardBorder }
        Text {
            text: "Valider un package_manifest.json"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
        }
        MeowTextArea {
            id: manifestArea
            objectName: "libraryManifestArea"
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(180)
            text: '{\n'
                  + '  "manifestVersion": 1,\n'
                  + '  "id": "demo-cat",\n'
                  + '  "version": "1.0.0",\n'
                  + '  "kind": "asset3d",\n'
                  + '  "minGameVersion": "3.0.0",\n'
                  + '  "signature": "",\n'
                  + '  "publisherKeyId": "",\n'
                  + '  "budgets": { "packageSizeBytes": 1024, "triangles": 2000, "maxTextureSize": 1024 }\n'
                  + '}'
            wrapMode: TextEdit.NoWrap
            font.family: "Consolas"
            font.pixelSize: Theme.fontSizeCaption
            color: root.host.textPrimary
        }
        RowLayout {
            Layout.fillWidth: true
            MeowButton {
                objectName: "libraryValidateButton"
                text: "Valider manifeste"
                font.pixelSize: Theme.fontSizeSmall
                onClicked: root._validate()
            }
            Text {
                text: root._validation || "Aucune validation lancée."
                color: root._validation.indexOf('"ok": true') >= 0
                       ? Theme.success : root.host.textSecondary
                font.pixelSize: Theme.fontSizeCaption
                font.family: "Consolas"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }
    }
}
