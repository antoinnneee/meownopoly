import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts 1.15
import "../editorBottomPanel"
import "."

import MapInfo
import AssetManager 1.0
import MapTypes

Item {
    id: backgroundView
    width: parent.width
    height: backgroundLayout.height

    property string currentThemeMode: "default" // "default" or "custom"

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
        
        // Contrôles d'affichage communs (au-dessus des boutons de sélection de thème)
        Rectangle {
            width: parent.width - parent.padding * 2
            color: "#333333"
            radius: 6
            border.color: "#444444"
            border.width: 1
            height: commonControlsColumn.height + 20
            visible: logic.mapInfo.backgroundPath !== ""

            Column {
                id: commonControlsColumn
                width: parent.width - 20
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 10
                spacing: 10

                // Mode d'affichage
                Text {
                    text: "Mode d'affichage:"
                    color: "#FFFFFF"
                    font.pixelSize: 14
                    font.bold: true
                    height: 20
                }

                // Snap to grid checkbox
                CheckBox {
                    id: commonSnapToGridCheckBox
                    text: "Fixé à la grille ?"
                    width: parent.width
                    checked: logic.mapInfo.isBackgroundOnGrill

                    indicator: Rectangle {
                        implicitWidth: 20
                        implicitHeight: 20
                        x: commonSnapToGridCheckBox.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 3
                        border.color: "#4A90E2"
                        border.width: 1
                        color: commonSnapToGridCheckBox.checked ? "#4A90E2" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            font.pixelSize: 14
                            color: "white"
                            visible: commonSnapToGridCheckBox.checked
                        }
                    }

                    contentItem: Text {
                        text: commonSnapToGridCheckBox.text
                        font.pixelSize: 14
                        color: "#FFFFFF"
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: commonSnapToGridCheckBox.indicator.width + commonSnapToGridCheckBox.spacing
                    }

                    onCheckedChanged: {
                            logic.mapInfo.isBackgroundOnGrill = checked
                            logic.saveMap(MapTypes.UNDOREDO)
                    }
                }

                // Boutons de mode d'affichage
                Row {
                    width: parent.width
                    height: 32
                    spacing: 10

                    Button {
                        text: "Stretch"
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
                            logic.saveMap(MapTypes.UNDOREDO)
                        }
                    }

                    Button {
                        text: "Fit"
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
                            logic.saveMap(MapTypes.UNDOREDO)
                        }
                    }

                    ColumnLayout {
                        width: (parent.width - 20) / 3
                        spacing: 4
                        
                        Button {
                            text: "Tile"
                            Layout.fillWidth: true
                            Layout.maximumHeight: 24
                            height: 20

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
                                logic.saveMap(MapTypes.UNDOREDO)
                            }
                        }
                        
                        Slider {
                            id: commonTileSizeSlider
                            Layout.fillWidth: true
                            from: 20
                            to: 400
                            stepSize: 20
                            value: 100
                            visible: logic.mapInfo.backgroundScaling === "Tile"
                            enabled: logic.mapInfo.backgroundScaling === "Tile"
                            
                            onValueChanged: {
                                if (typeof logic !== 'undefined' && typeof logic.mapInfo !== 'undefined') {
                                    logic.mapInfo.backgroundTileSize = value
                                }
                            }
                            
                            onPressedChanged: {
                                // Sauvegarder seulement quand l'utilisateur relâche le slider
                                if (!pressed && typeof logic !== 'undefined') {
                                    logic.saveMap(MapTypes.UNDOREDO)
                                }
                            }

                            background: Rectangle {
                                x: commonTileSizeSlider.leftPadding
                                y: commonTileSizeSlider.topPadding + commonTileSizeSlider.availableHeight / 2 - height / 2
                                width: commonTileSizeSlider.availableWidth
                                height: 4
                                radius: 2
                                color: "#333333"

                                Rectangle {
                                    width: commonTileSizeSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: "#4A90E2"
                                    radius: 2
                                }
                            }
                            
                            handle: Rectangle {
                                x: commonTileSizeSlider.leftPadding + commonTileSizeSlider.visualPosition * (commonTileSizeSlider.availableWidth - width)
                                y: commonTileSizeSlider.topPadding + commonTileSizeSlider.availableHeight / 2 - height / 2
                                width: 16
                                height: 16
                                radius: 8
                                color: commonTileSizeSlider.pressed ? "#FFFFFF" : "#F0F0F0"
                                border.color: "#4A90E2"
                            }
                        }
                    }
                }
            }
        }

        // Indicateurs de sélection de thème (non cliquables)
        Row {
            width: parent.width - parent.padding * 2
            height: 40
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter

            // Indicateur Thème par défaut
            Rectangle {
                id: defaultThemeIndicator
                width: parent.width / 2 - 5
                height: parent.height
                color: backgroundView.currentThemeMode === "default" ? "#4A90E2" : "#333333"
                radius: 6
                border.width: 1
                border.color: backgroundView.currentThemeMode === "default" ? "#FFFFFF" : "#555555"

                Text {
                    anchors.centerIn: parent
                    text: "Thème par défaut"
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Indicateur Thème personnalisé
            Rectangle {
                id: customThemeIndicator
                width: parent.width / 2 - 5
                height: parent.height
                color: backgroundView.currentThemeMode === "custom" ? "#4A90E2" : "#333333"
                radius: 6
                border.width: 1
                border.color: backgroundView.currentThemeMode === "custom" ? "#FFFFFF" : "#555555"

                Text {
                    anchors.centerIn: parent
                    text: "Thème personnalisé"
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Controls container - affichage côte à côte
        Rectangle {
            width: parent.width - parent.padding * 2
            color: "#333333"
            radius: 6
            border.color: "#444444"
            border.width: 1
            height: Math.max(defaultThemesContainer.height, customThemeContainer.height) + 20

            Row {
                width: parent.width - 20
                height: parent.height - 20
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 10
                spacing: 10

                // Conteneur pour les thèmes par défaut (moitié gauche)
                Rectangle {
                    id: defaultThemesContainer
                    width: (parent.width - parent.spacing) / 2
                    height: defaultThemesColumn.height
                    color: "transparent"

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
                                        backgroundView.currentThemeMode = "default"
                                        logic.saveMap(MapTypes.UNDOREDO)
                                    }
                                }
                            }
                        }

                        // Information sur le mode d'affichage
                        Text {
                            text: "Utilisez les contrôles d'affichage ci-dessus pour ajuster l'arrière-plan."
                            color: "#AAAAAA"
                            font.pixelSize: 12
                            height: 20
                            width: parent.width
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            visible: logic.mapInfo.backgroundIndex !== -1
                        }
                    }
                }

                // Conteneur pour le thème personnalisé (moitié droite)
                Rectangle {
                    id: customThemeContainer
                    width: (parent.width - parent.spacing) / 2
                    height: customThemeColumn.height
                    color: "transparent"

                    Column {
                        id: customThemeColumn
                        width: parent.width
                        spacing: 10

                        Text {
                            text: "Thème personnalisé:"
                            color: "#FFFFFF"
                            font.pixelSize: 14
                            font.bold: true
                            height: 20
                        }

                        MSP_SP_BackgroundSelector {
                            id: backgroundSelector
                            width: parent.width
                            
                            // Ajouter un signal pour détecter quand l'utilisateur clique sur la caméra
                            onBackgroundSelected: {
                                backgroundView.currentThemeMode = "custom"
                            }
                        }
                        
                        // Information sur le mode d'affichage
                        Text {
                            text: "Utilisez les contrôles d'affichage ci-dessus pour ajuster l'arrière-plan."
                            color: "#AAAAAA"
                            font.pixelSize: 12
                            height: 20
                            width: parent.width
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            visible: logic.mapInfo.backgroundPath !== ""
                        }
                    }
                }
            }
        }
    }
}
