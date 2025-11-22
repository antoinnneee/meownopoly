/*
 * ModelsSection.qml - Gestion des modèles 3D
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 250 // Plus grand pour la liste
    color: "#3a3a3a"
    radius: 10
    border.color: "#555555"
    border.width: 1

    property var modelsList: []
    property bool isDownloading: false
    
    signal refreshRequested()
    signal downloadRequested(string name, string version)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "🧸 Modèles 3D Disponibles"
                font.pixelSize: 16
                font.bold: true
                color: "#ffffff"
                Layout.fillWidth: true
            }
            
            Button {
                text: "Actualiser"
                onClicked: root.refreshRequested()
                background: Rectangle {
                    color: "#444"
                    radius: 4
                    border.color: "#666"
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
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
                color: index % 2 === 0 ? "#444444" : "#3e3e3e"
                radius: 4

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: modelData.name
                        color: "white"
                        font.bold: true
                        Layout.preferredWidth: 150
                    }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        
                        // Sélecteur de version
                        ComboBox {
                            id: versionSelector
                            Layout.fillWidth: true
                            Layout.maximumWidth: 150
                            Layout.preferredHeight: 30
                            
                            model: modelData.versions
                            textRole: "version"
                            
                            background: Rectangle {
                                color: "#2a2a2a"
                                border.color: "#555"
                                radius: 4
                            }
                            contentItem: Text {
                                text: parent.displayText
                                color: "white"
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 10
                                font.pixelSize: 12
                            }
                            
                            Component.onCompleted: currentIndex = 0
                        }
                        
                        // Indicateur d'installation
                        Text {
                            text: modelData.isInstalled ? "Installé: v" + modelData.localVersion : "Non installé"
                            color: modelData.isInstalled ? "#4caf50" : "#888" // Vert si installé
                            font.pixelSize: 10
                        }
                    }

                    Item { Layout.fillWidth: true } // Spacer

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
                            color: parent.enabled ? (actionButton.isSameVersion ? "#555" : "#2196f3") : "#666"
                            radius: 4
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
                        }
                    }
                }
            }
            
            Text {
                anchors.centerIn: parent
                text: "Aucun modèle disponible"
                color: "#888"
                visible: listView.count === 0
            }
        }
    }
}

