/*
 * ModelsSection.qml - Gestion des modèles 3D
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import theme

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
    
    signal refreshRequested()
    signal downloadRequested(string name, string version)
    signal editRequested(string name)

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

            Button {
                text: "Actualiser"
                onClicked: root.refreshRequested()
                background: Rectangle {
                    color: Theme.border
                    radius: Theme.radiusS
                    border.color: Theme.textDisabled
                }
                contentItem: Text {
                    text: parent.text
                    color: Theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
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
                    Button {
                        id: editButton
                        visible: modelData.isInstalled
                        text: "Éditer"
                        onClicked: root.editRequested(modelData.name)
                        background: Rectangle {
                            color: editButton.pressed ? "#6d28d9" : "#7c3aed"
                            radius: Theme.radiusS
                        }
                        contentItem: Text {
                            text: editButton.text
                            color: Theme.textPrimary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: Theme.fontSizeBody
                        }
                    }

                    Button {
                        id: actionButton
                        // Texte dynamique selon l'état
                        property bool isUpdate: modelData.isInstalled && versionSelector.currentText !== modelData.localVersion
                        property bool isSameVersion: modelData.isInstalled && versionSelector.currentText === modelData.localVersion
                        
                        text: isSameVersion ? "Réinstaller" : (modelData.isInstalled ? "Mettre à jour" : "Télécharger")
                        
                        enabled: !root.isDownloading
                        onClicked: {
                            root.downloadRequested(modelData.name, versionSelector.currentText)
                        }
                        background: Rectangle {
                            color: parent.enabled ? (actionButton.isSameVersion ? Theme.borderLight : Theme.accent) : Theme.textDisabled
                            radius: Theme.radiusS
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
            }
            
            Text {
                anchors.centerIn: parent
                text: "Aucun modèle disponible"
                color: Theme.textMuted
                visible: listView.count === 0
            }
        }
    }
}

