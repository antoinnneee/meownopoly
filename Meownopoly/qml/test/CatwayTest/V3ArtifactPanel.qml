import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeowArtifacts 1.0
import theme
import ui_item

Rectangle {
    id: root
    required property var host
    property var _hashes: []
    property var _manifest: ({})
    property string _content: ""
    property string _status: ""
    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1
    implicitHeight: contentColumn.implicitHeight + Theme.spacingXXL * 2

    function _refresh(preferredHash) {
        const hashes = ArtifactRegistry.knownHashes()
        root._hashes = hashes
        if (hashes.length === 0) {
            root._manifest = ({})
            root._content = ""
            return
        }
        const wanted = preferredHash || hashCombo.currentText
        const index = Math.max(0, hashes.indexOf(wanted))
        hashCombo.currentIndex = index
        root._select(hashes[index])
    }

    function _select(hash) {
        if (!hash) return
        root._manifest = ArtifactRegistry.manifestInfo(hash)
        root._content = ArtifactRegistry.contentText(hash)
    }

    function _register() {
        const hash = ArtifactRegistry.registerTextArtifact(
                       sourceArea.text, kindCombo.currentText,
                       authorField.text || "harness")
        root._status = hash ? "Artefact enregistré : " + hash : "Échec de l'enregistrement"
        root._refresh(hash)
    }

    Component.onCompleted: root._refresh("")
    Connections {
        target: ArtifactRegistry
        function onArtifactRegistered(contentHash) { root._refresh(contentHash) }
        function onArtifactPurged(contentHash) {
            root._status = "Artefact purgé : " + contentHash
            root._refresh("")
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingM
        Text {
            text: "Artefacts par hash"
            color: root.host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
        }
        Text {
            text: "T4-1 · ArtifactRegistry · blob + manifeste + refcount + GC"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            font.italic: true
            Layout.fillWidth: true
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            MeowComboBox {
                id: kindCombo
                objectName: "artifactKindCombo"
                model: ["qml", "primitive", "module", "asset3d", "skin"]
                Layout.preferredWidth: Theme.px(120)
                font.pixelSize: Theme.fontSizeSmall
            }
            MeowTextField {
                id: authorField
                objectName: "artifactAuthorField"
                text: "harness"
                placeholderText: "auteur"
                Layout.fillWidth: true
                font.pixelSize: Theme.fontSizeSmall
            }
        }
        MeowTextArea {
            id: sourceArea
            objectName: "artifactSourceArea"
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(92)
            text: "import QtQuick\nItem { property int value: 3 }"
            wrapMode: TextEdit.Wrap
            font.family: "Consolas"
            font.pixelSize: Theme.fontSizeSmall
            color: root.host.textPrimary
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            MeowButton {
                objectName: "artifactRegisterButton"
                text: "Enregistrer"
                font.pixelSize: Theme.fontSizeSmall
                onClicked: root._register()
            }
            MeowButton {
                objectName: "artifactRefreshButton"
                text: "Actualiser"
                font.pixelSize: Theme.fontSizeSmall
                onClicked: root._refresh("")
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root._hashes.length + " artefact(s)"
                color: root.host.textSecondary
                font.pixelSize: Theme.fontSizeSmall
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.host.cardBorder }
        MeowComboBox {
            id: hashCombo
            objectName: "artifactHashCombo"
            Layout.fillWidth: true
            model: root._hashes
            font.family: "Consolas"
            font.pixelSize: Theme.fontSizeCaption
            onCurrentTextChanged: root._select(currentText)
        }
        GridLayout {
            columns: 2
            columnSpacing: Theme.spacingXL
            rowSpacing: Theme.spacingXS
            Layout.fillWidth: true
            Text { text: "disponible"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                text: hashCombo.currentText ? ArtifactRegistry.isAvailable(hashCombo.currentText) : false
                color: text === "true" ? Theme.success : Theme.warning
                font.pixelSize: Theme.fontSizeSmall
                font.family: "Consolas"
            }
            Text { text: "kind / auteur"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                text: (root._manifest.kind || "—") + " / " + (root._manifest.author || "—")
                color: root.host.textPrimary
                font.pixelSize: Theme.fontSizeSmall
                Layout.fillWidth: true
            }
            Text { text: "refcount"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                text: hashCombo.currentText ? ArtifactRegistry.refCountOf(hashCombo.currentText) : 0
                color: root.host.textPrimary
                font.pixelSize: Theme.fontSizeSmall
                font.family: "Consolas"
            }
        }
        Text {
            text: root._content || "Aucun contenu sélectionné."
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            font.family: "Consolas"
            Layout.fillWidth: true
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 4
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.fillWidth: true
            MeowCheckBox {
                id: keepSelectedCheck
                objectName: "artifactKeepSelectedCheck"
                text: "conserver la sélection"
                checked: true
                font.pixelSize: Theme.fontSizeCaption
            }
            MeowButton {
                objectName: "artifactGcButton"
                text: "GC non référencés"
                font.pixelSize: Theme.fontSizeSmall
                onClicked: {
                    const live = keepSelectedCheck.checked && hashCombo.currentText
                               ? [hashCombo.currentText] : []
                    const count = ArtifactRegistry.collectGarbageList(live)
                    root._status = count + " artefact(s) purgé(s)"
                    root._refresh("")
                }
            }
        }
        Text {
            objectName: "artifactStatusLabel"
            text: root._status
            visible: text !== ""
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
}
