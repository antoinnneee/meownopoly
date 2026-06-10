/*
 * PackagingSection.qml - Section de création et d'upload des paquets de ressources
 *
 * Cette section permet de :
 * - Créer de nouveaux paquets de ressources
 * - Gérer les versions automatiquement
 * - Uploader les paquets vers le serveur
 *
 * Fonctionnalités :
 * ----------------
 * - Sélection du dossier source via dialogue
 * - Numérotation automatique des versions
 * - Compression des ressources au format .meow
 * - Upload avec barre de progression
 *
 * Format des paquets :
 * ------------------
 * - Nom : assets_vX.X.X.meow
 * - Structure : Dossier compressé avec manifest
 * - Versions : Incrémentation automatique du patch
 *   Exemple : 1.0.3 -> 1.0.4
 *
 * États :
 * ------
 * - packageCreated : Indique si un paquet est prêt
 * - isDownloading : Bloque pendant l'upload
 * - currentVersion : Version actuelle du système
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import theme

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 220
    color: Theme.surfaceHover
    radius: Theme.radiusXL
    border.color: Theme.borderLight
    border.width: 1
    
    property bool packageCreated: false
    property bool isDownloading: false
    property alias packageVersion: packageVersionField.text
    property alias selectedFolder: selectedFolderLabel.text
    property string currentVersion: "0.0.0"  // Version actuelle du système
    property bool isModelMode: typeSwitch.checked
    property alias modelName: modelNameField.text
    
    signal createPackageRequested(string folderPath, string version)
    signal createModelPackageRequested(string folderPath, string name, string version)
    signal uploadPackageRequested()
    signal uploadModelRequested(string name, string version)
    signal openModelConfiguratorRequested()
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingL

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "📦 Création de paquets"
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                color: Theme.textPrimary
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "🧩 Configurer un modèle 3D"
                onClicked: root.openModelConfiguratorRequested()
                background: Rectangle {
                    color: parent.pressed ? Theme.pressed(Theme.accent) : Theme.accent
                    radius: Theme.radiusS
                }
                contentItem: Text {
                    text: parent.text
                    color: Theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizeBody
                    padding: Theme.spacingS
                }
            }

            Text {
                text: "Assets Jeu"
                color: !typeSwitch.checked ? Theme.textPrimary : Theme.textMuted
            }
            Switch {
                id: typeSwitch
                text: ""
            }
            Text {
                text: "Modèle 3D"
                color: typeSwitch.checked ? Theme.textPrimary : Theme.textMuted
            }
        }

        RowLayout {
            Layout.fillWidth: true

            RowLayout {
                spacing: Theme.spacingXS
                Layout.fillWidth: true

                // Champ Nom du Modèle (visible seulement en mode modèle)
                TextField {
                    id: modelNameField
                    visible: root.isModelMode
                    Layout.preferredWidth: 150
                    placeholderText: "Nom du modèle (ex: PionChat)"
                    color: Theme.textPrimary
                    background: Rectangle {
                        color: Theme.surface
                        border.color: Theme.borderLight
                        border.width: 1
                        radius: Theme.radiusS
                    }
                }

                TextField {
                    id: packageVersionField
                    Layout.fillWidth: true
                    placeholderText: "Version du paquet (ex: 1.0.1)"
                    // En mode modèle, on ne pré-remplit pas forcément avec la version du jeu
                    text: root.isModelMode ? "1.0.0" : logic.getNextVersion(root.currentVersion)
                    color: Theme.textPrimary

                    background: Rectangle {
                        color: Theme.surface
                        border.color: Theme.borderLight
                        border.width: 1
                        radius: Theme.radiusS
                    }
                }
            }

            Button {
                text: "Sélectionner dossier"
                onClicked: folderDialog.open()

                background: Rectangle {
                    color: parent.pressed ? "#5d4037" : "#795548"
                    radius: Theme.radiusM
                }

                contentItem: Text {
                    text: parent.text
                    color: Theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizeBody
                }
            }
        }

        Text {
            id: selectedFolderLabel
            text: "Aucun dossier sélectionné"
            color: Theme.textMuted
            Layout.fillWidth: true
            elide: Text.ElideMiddle
        }
        
        RowLayout {
            Layout.fillWidth: true
            
            Button {
                text: "Créer le paquet"
                enabled: selectedFolderLabel.text !== "Aucun dossier sélectionné" && 
                         packageVersionField.text.length > 0 && 
                         (!root.isModelMode || modelNameField.text.length > 0)
                         
                onClicked: {
                    if (root.isModelMode) {
                        root.createModelPackageRequested(selectedFolderLabel.text, modelNameField.text, packageVersionField.text)
                    } else {
                        root.createPackageRequested(selectedFolderLabel.text, packageVersionField.text)
                    }
                }
                
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? Theme.pressed(Theme.success) : Theme.success) : Theme.textDisabled
                    radius: Theme.radiusM
                }

                contentItem: Text {
                    text: parent.text
                    color: Theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizeBody
                }
            }
            
            Button {
                text: "Uploader vers serveur"
                enabled: root.packageCreated && !root.isDownloading
                onClicked: {
                    if (root.isModelMode) {
                        root.uploadModelRequested(modelNameField.text, packageVersionField.text)
                    } else {
                        root.uploadPackageRequested()
                    }
                }
                
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? Theme.pressed(Theme.accent) : Theme.accent) : Theme.textDisabled
                    radius: Theme.radiusM
                }

                contentItem: Text {
                    text: parent.text
                    color: Theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizeBody
                }
            }
            
            Item { Layout.fillWidth: true }
        }
    }
    
    // Dialog pour sélectionner un dossier
    FolderDialog {
        id: folderDialog
        title: "Sélectionner le dossier de ressources à packager"
        onAccepted: {
            selectedFolderLabel.text = selectedFolder.toString().replace("file:///", "")
        }
    }
}
