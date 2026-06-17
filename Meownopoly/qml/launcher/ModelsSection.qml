/*
 * ModelsSection.qml - Gestion des modèles 3D
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import theme
import ui_item

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 250 // Plus grand pour la liste
    color: Theme.surfaceHover
    radius: Theme.radiusXL
    border.color: Theme.borderLight
    border.width: 1

    property var modelsList: []
    property bool isDownloading: false
    // Active les actions serveur (suppression distante) : nécessite un token d'upload.
    property bool canManageServer: false

    signal refreshRequested()
    signal downloadRequested(string name, string version)
    signal editRequested(string name)
    signal deleteRequested(string name)
    signal deleteFromServerRequested(string name, string version)

    // Nom du modèle en attente de confirmation de suppression locale.
    property string _pendingDeleteName: ""
    // Modèle/version en attente de confirmation de suppression serveur.
    property string _pendingServerDeleteName: ""
    property string _pendingServerDeleteVersion: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingL

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "🧸 Modèles 3D Disponibles"
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                color: Theme.textPrimary
                Layout.fillWidth: true
            }

            MeowButton {
                text: "Actualiser"
                variant: "secondary"
                fontSize: Theme.fontSizeBody
                hoverZoom: false
                onClicked: root.refreshRequested()
            }
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.modelsList

            delegate: Rectangle {
                width: listView.width
                height: 50
                color: index % 2 === 0 ? Theme.border : Theme.surfaceHover
                radius: Theme.radiusS

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingL

                    Text {
                        text: modelData.name
                        color: Theme.textPrimary
                        font.bold: true
                        Layout.preferredWidth: 150
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXXS
                        
                        // Sélecteur de version
                        ComboBox {
                            id: versionSelector
                            Layout.fillWidth: true
                            Layout.maximumWidth: 150
                            Layout.preferredHeight: 30
                            
                            model: modelData.versions
                            textRole: "version"
                            
                            background: Rectangle {
                                color: Theme.surface
                                border.color: Theme.borderLight
                                radius: Theme.radiusS
                            }
                            contentItem: Text {
                                text: parent.displayText
                                color: Theme.textPrimary
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: Theme.spacingL
                                font.pixelSize: Theme.fontSizeBody
                            }

                            Component.onCompleted: currentIndex = 0
                        }

                        // Indicateur d'installation
                        Text {
                            text: modelData.isInstalled ? "Installé: v" + modelData.localVersion : "Non installé"
                            color: modelData.isInstalled ? Theme.success : Theme.textMuted // Vert si installé
                            font.pixelSize: Theme.fontSizeCaption
                        }
                    }

                    Item { Layout.fillWidth: true } // Spacer

                    // Éditer : ouvre le configurateur sur le dossier installé du modèle.
                    MeowButton {
                        id: editButton
                        visible: modelData.isInstalled
                        text: "Éditer"
                        baseColor: "#7c3aed"
                        fontSize: Theme.fontSizeBody
                        hoverZoom: false
                        glossy: false
                        onClicked: root.editRequested(modelData.name)
                    }

                    // Supprimer : efface le modèle téléchargé localement.
                    MeowButton {
                        id: deleteButton
                        visible: modelData.isInstalled
                        text: "Supprimer"
                        baseColor: "#dc2626"
                        fontSize: Theme.fontSizeBody
                        hoverZoom: false
                        glossy: false
                        onClicked: {
                            root._pendingDeleteName = modelData.name
                            confirmDeleteDialog.open()
                        }
                    }

                    // Suppression serveur : retire la version sélectionnée du serveur
                    // (action admin, nécessite un token d'upload configuré).
                    MeowButton {
                        id: serverDeleteButton
                        visible: root.canManageServer
                        text: "Suppr. serveur"
                        baseColor: "#991b1b"
                        fontSize: Theme.fontSizeBody
                        hoverZoom: false
                        glossy: false
                        onClicked: {
                            root._pendingServerDeleteName = modelData.name
                            root._pendingServerDeleteVersion = versionSelector.currentText
                            confirmServerDeleteDialog.open()
                        }
                    }

                    MeowButton {
                        id: actionButton
                        // Texte dynamique selon l'état
                        property bool isUpdate: modelData.isInstalled && versionSelector.currentText !== modelData.localVersion
                        property bool isSameVersion: modelData.isInstalled && versionSelector.currentText === modelData.localVersion

                        text: isSameVersion ? "Réinstaller" : (modelData.isInstalled ? "Mettre à jour" : "Télécharger")
                        baseColor: actionButton.isSameVersion ? Theme.borderLight : Theme.accent
                        fontSize: Theme.fontSizeBody
                        hoverZoom: false
                        glossy: false

                        enabled: !root.isDownloading
                        onClicked: {
                            root.downloadRequested(modelData.name, versionSelector.currentText)
                        }
                    }
                }
            }
            
            Text {
                anchors.centerIn: parent
                text: "Aucun modèle disponible"
                color: Theme.textMuted
                visible: listView.count === 0
            }
        }
    }

    // Confirmation avant de supprimer un modèle téléchargé localement.
    Dialog {
        id: confirmDeleteDialog
        anchors.centerIn: Overlay.overlay
        modal: true
        title: "Supprimer le modèle"
        standardButtons: Dialog.Yes | Dialog.No

        contentItem: Text {
            text: "Supprimer définitivement le modèle « " + root._pendingDeleteName + " » téléchargé ?"
            color: Theme.textPrimary
            wrapMode: Text.WordWrap
        }

        onAccepted: {
            if (root._pendingDeleteName.length > 0)
                root.deleteRequested(root._pendingDeleteName)
            root._pendingDeleteName = ""
        }
        onRejected: root._pendingDeleteName = ""
    }

    // Confirmation avant de supprimer un modèle du SERVEUR (irréversible, partagé).
    Dialog {
        id: confirmServerDeleteDialog
        anchors.centerIn: Overlay.overlay
        modal: true
        title: "Supprimer du serveur"
        standardButtons: Dialog.Yes | Dialog.No

        contentItem: Text {
            text: "Supprimer définitivement « " + root._pendingServerDeleteName
                  + " » v" + root._pendingServerDeleteVersion
                  + " du serveur ?\nCette action affecte tous les utilisateurs."
            color: Theme.textPrimary
            wrapMode: Text.WordWrap
        }

        onAccepted: {
            if (root._pendingServerDeleteName.length > 0)
                root.deleteFromServerRequested(root._pendingServerDeleteName,
                                               root._pendingServerDeleteVersion)
            root._pendingServerDeleteName = ""
            root._pendingServerDeleteVersion = ""
        }
        onRejected: {
            root._pendingServerDeleteName = ""
            root._pendingServerDeleteVersion = ""
        }
    }
}

