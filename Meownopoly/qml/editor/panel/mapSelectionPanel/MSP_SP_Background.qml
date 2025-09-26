import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts 1.15
import "../editorBottomPanel"
import "."

import MapInfo
import AssetManager 1.0

Item {
    id: backgroundView
    visible: contentArea.currentView === "background"
    width: parent.width
    height: backgroundLayout.height
    anchors.top: titleSection.bottom

    property string currentThemeMode: "default" // "default" or "custom"

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: "red"
    }

    Column {
        id: backgroundLayout
        width: parent.width
        spacing: 10 // réduit l'espacement
        padding: 5 // réduit le padding

        // Header avec titre, format standard
        Rectangle {
            width: parent.width - parent.padding * 2
            height: 40
            color: "#383838"
            radius: 6

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                spacing: 10

                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: "#E91E63"
                    opacity: 0.2

                    Text {
                        anchors.centerIn: parent
                        text: "🖼️"
                        font.pixelSize: 16
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Background Settings"
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                }
            }
        }

        // Boutons de sélection de thème
        Row {
            width: parent.width - parent.padding * 2
            height: 40
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter

            // Bouton Thème par défaut
            Button {
                id: defaultThemeButton
                width: parent.width / 2 - 5
                height: parent.height
                text: "Thème par défaut"

                background: Rectangle {
                    color: backgroundView.currentThemeMode === "default" ? "#4A90E2" : "#333333"
                    radius: 6
                    border.width: 1
                    border.color: backgroundView.currentThemeMode === "default" ? "#FFFFFF" : "#555555"
                }

                contentItem: Text {
                    text: defaultThemeButton.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    backgroundView.currentThemeMode = "default"
                }
            }

            // Bouton Thème personnalisé
            Button {
                id: customThemeButton
                width: parent.width / 2 - 5
                height: parent.height
                text: "Thème personnalisé"

                background: Rectangle {
                    color: backgroundView.currentThemeMode === "custom" ? "#4A90E2" : "#333333"
                    radius: 6
                    border.width: 1
                    border.color: backgroundView.currentThemeMode === "custom" ? "#FFFFFF" : "#555555"
                }

                contentItem: Text {
                    text: customThemeButton.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    backgroundView.currentThemeMode = "custom"
                }
            }
        }

        // Controls container
        Rectangle {
            width: parent.width - parent.padding * 2
            color: "#333333"
            radius: 6
            border.color: "#444444"
            border.width: 1
            height: (backgroundView.currentThemeMode === "default" ? defaultThemesContainer.height : customThemeContainer.height) + 20

            // Conteneur pour les thèmes par défaut
            Item {
                id: defaultThemesContainer
                width: parent.width - 20
                height: defaultThemesColumn.height
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 10
                visible: backgroundView.currentThemeMode === "default"

                Column {
                    id: defaultThemesColumn
                    width: parent.width
                    spacing: 10

                    Text {
                        text: "Sélectionner un arrière-plan:"
                        color: "#FFFFFF"
                        font.pixelSize: 14
                        font.bold: true
                        height: 20
                    }

                    // Liste des thèmes par défaut
                    ListView {
                        id: defaultThemesList
                        width: parent.width
                        height: 300
                        spacing: 10
                        clip: true
                        model: AssetManager.getAvailableBackgrounds()

                        delegate: Rectangle {
                            width: defaultThemesList.width
                            height: 90
                            radius: 8
                            border.width: logic.mapInfo.backgroundIndex === index ? 3 : 1
                            border.color: logic.mapInfo.backgroundIndex === index ? "#4A90E2" : "#555555"

                            Image {
                                id: bgImage
                                anchors.fill: parent
                                anchors.margins: 2
                                source: modelData
                                fillMode: Image.PreserveAspectCrop
                            }

                            // Caption overlay
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 26
                                color: "#80000000"

                                Text {
                                    anchors.centerIn: parent
                                    // Extraire le nom du fichier à partir du chemin complet et enlever l'extension
                                    text: {
                                        var path = modelData;
                                        var fileName = path.substring(path.lastIndexOf("/") + 1);
                                        return fileName.replace(/\.[^/.]+$/, ""); // Enlever l'extension
                                    }
                                    color: "white"
                                    font.pixelSize: 14
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    logic.mapInfo.backgroundPath = bgImage.source
                                    logic.mapInfo.backgroundScaling = "Fit" // Valeur par défaut
                                }
                            }
                        }
                    }

                    // Mode d'affichage
                    Text {
                        text: "Mode d'affichage:"
                        color: "#FFFFFF"
                        font.pixelSize: 14
                        height: 20
                        visible: logic.mapInfo.backgroundIndex !== -1
                    }

                    // Snap to grid checkbox
                    CheckBox {
                        id: snapToGridCheckBox
                        text: "Fixé à la grille ?"
                        width: parent.width
                        checked: logic.mapInfo.isBackgroundOnGrill

                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: snapToGridCheckBox.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 3
                            border.color: "#4A90E2"
                            border.width: 1
                            color: snapToGridCheckBox.checked ? "#4A90E2" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                font.pixelSize: 14
                                color: "white"
                                visible: snapToGridCheckBox.checked
                            }
                        }

                        contentItem: Text {
                            text: snapToGridCheckBox.text
                            font.pixelSize: 14
                            color: "#FFFFFF"
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: snapToGridCheckBox.indicator.width + snapToGridCheckBox.spacing
                        }

                        onCheckedChanged: {
                            logic.mapInfo.isBackgroundOnGrill = checked
                        }
                    }

                    // Boutons de mode d'affichage
                    Row {
                        width: parent.width
                        height: 32
                        spacing: 10
                        visible: logic.mapInfo.backgroundIndex !== -1

                        Button {
                            text: "stretch"
                            width: (parent.width - 20) / 3
                            height: parent.height

                            background: Rectangle {
                                color: logic.mapInfo.backgroundScaling === "Stretch" ? "#4A90E2" : "#333333"
                                radius: 6
                            }

                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                logic.mapInfo.backgroundScaling = "Stretch"
                            }
                        }

                        Button {
                            text: "fill"
                            width: (parent.width - 20) / 3
                            height: parent.height

                            background: Rectangle {
                                color: logic.mapInfo.backgroundScaling === "Fit" ? "#4A90E2" : "#333333"
                                radius: 6
                            }

                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                logic.mapInfo.backgroundScaling = "Fit"
                            }
                        }

                        Button {
                            text: "tile"
                            width: (parent.width - 20) / 3
                            height: parent.height

                            background: Rectangle {
                                color: logic.mapInfo.backgroundScaling === "Tile" ? "#4A90E2" : "#333333"
                                radius: 6
                            }

                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                logic.mapInfo.backgroundScaling = "Tile"
                            }
                        }
                    }
                }
            }

            // Conteneur pour le thème personnalisé
            Item {
                id: customThemeContainer
                width: parent.width - 20
                height: customThemeColumn.height
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 10
                visible: backgroundView.currentThemeMode === "custom"

                Column {
                    id: customThemeColumn
                    width: parent.width
                    spacing: 10

                    MSP_SP_BackgroundSelector {
                        width: parent.width
                    }
                }
            }
        }
    }
}
