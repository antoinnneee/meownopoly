import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeowSave 1.0
import MeowRules 1.0
import theme
import ui_item

// T4-2 / M7 — format de sauvegarde de partie distinct des maps.
Rectangle {
    id: root
    required property var host
    property var _saves: []
    property string _preview: ""
    property string _status: ""

    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1
    implicitHeight: contentColumn.implicitHeight + Theme.spacingXXL * 2

    GameSave { id: saveDocument }

    function _refresh() {
        root._saves = saveDocument.availableSaveNames()
    }

    function _capture() {
        saveDocument.captureRuntimeState()
        const doc = saveDocument.toVariantMap()
        doc.saveName = saveNameField.text || "partie_v3"
        doc.rulebook = RulesEngine.rulebookMap()
        saveDocument.loadVariantMap(doc)
        root._preview = JSON.stringify(saveDocument.toVariantMap(), null, 2)
    }

    function _save() {
        root._capture()
        const name = saveNameField.text || "partie_v3"
        const ok = saveDocument.saveToFile(name)
        root._status = ok ? "Sauvegardé : " + saveDocument.saveFilePathFor(name)
                          : "Échec de la sauvegarde"
        root._refresh()
    }

    function _load() {
        const name = saveCombo.currentText || saveNameField.text
        if (!name) return
        const ok = saveDocument.loadFromFile(name)
        root._status = ok ? "Chargé : " + saveDocument.saveFilePathFor(name)
                          : "Sauvegarde introuvable ou invalide"
        if (ok) {
            saveNameField.text = name
            root._preview = JSON.stringify(saveDocument.toVariantMap(), null, 2)
        }
    }

    Component.onCompleted: {
        root._refresh()
        root._capture()
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingM
        Text {
            text: "Sauvegardes de partie"
            color: root.host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
        }
        Text {
            text: "T4-2 · GameSave · runtime, mémoire, modules et règlement"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            font.italic: true
            Layout.fillWidth: true
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            MeowTextField {
                id: saveNameField
                objectName: "gameSaveNameField"
                text: "partie_v3"
                placeholderText: "nom de sauvegarde"
                Layout.fillWidth: true
                font.pixelSize: Theme.fontSizeSmall
            }
            MeowButton {
                objectName: "gameSaveCaptureButton"
                text: "Capturer"
                font.pixelSize: Theme.fontSizeSmall
                onClicked: root._capture()
            }
            MeowButton {
                objectName: "gameSaveWriteButton"
                text: "Sauvegarder"
                font.pixelSize: Theme.fontSizeSmall
                onClicked: root._save()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            MeowComboBox {
                id: saveCombo
                objectName: "gameSaveCombo"
                model: root._saves
                Layout.fillWidth: true
                font.pixelSize: Theme.fontSizeSmall
            }
            MeowButton {
                objectName: "gameSaveLoadButton"
                text: "Charger"
                enabled: saveCombo.currentText !== ""
                font.pixelSize: Theme.fontSizeSmall
                onClicked: root._load()
            }
            MeowButton {
                text: "Actualiser"
                font.pixelSize: Theme.fontSizeSmall
                onClicked: root._refresh()
            }
        }
        GridLayout {
            columns: 2
            columnSpacing: Theme.spacingXL
            rowSpacing: Theme.spacingXS
            Layout.fillWidth: true
            Text { text: "saveVersion"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: saveDocument.saveVersion; color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }
            Text { text: "saveId"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                text: saveDocument.saveId
                color: root.host.textPrimary
                font.pixelSize: Theme.fontSizeCaption
                font.family: "Consolas"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Text { text: "fichier"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                text: saveDocument.saveFilePathFor(saveNameField.text || "partie_v3")
                color: root.host.textPrimary
                font.pixelSize: Theme.fontSizeCaption
                font.family: "Consolas"
                Layout.fillWidth: true
                elide: Text.ElideMiddle
            }
        }
        MeowTextArea {
            objectName: "gameSavePreviewArea"
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(190)
            readOnly: true
            text: root._preview
            wrapMode: TextEdit.NoWrap
            font.family: "Consolas"
            font.pixelSize: Theme.fontSizeCaption
            color: root.host.textPrimary
        }
        Text {
            objectName: "gameSaveStatusLabel"
            text: root._status
            visible: text !== ""
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
}
