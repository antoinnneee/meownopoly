import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQml
import Game
import Case
import ItemSnapable
import "tools"
import "tools/snapable"
import "panel"
import "panel/assetSelectionPanel"
import MapLoader
import MapInfo
import EditorEnum
import QtQuick.Dialogs

Rectangle {
    id: menuMapAtStart
    width: parent.width * 0.5
    height: width
    radius : 12
    color: "#E6000000" // Semi-transparent black
    border.color: "#333333"
    border.width: 1
    anchors.centerIn: parent

    // Signal to show InfoPanel when confirmed - will be connected in Editor.qml
    signal backgroundSelected(int bgIndex, string displayMode)

    property int selectedBackground: -1
    property string selectedDisplayMode: "fill"
    property string selectedMap: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Header buttons
        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 10

            Button {
                id: chooseBackgroundBtn
                text: "Choisir fond d'écran"
                width: parent.width / 2 - 5
                height: parent.height
                checked: true

                onClicked: {
                    backgroundContent.visible = true
                    loadMapContent.visible = false
                }
            }

            Button {
                id: loadMapBtn
                text: "Charger une carte"
                width: parent.width / 2 - 5
                height: parent.height

                onClicked: {
                    backgroundContent.visible = false
                    loadMapContent.visible = true
                }
            }
        }

        // Background selection content
        Rectangle {
            id: backgroundContent
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            visible: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 10

                // Display mode buttons
                Row {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    spacing: 10

                    Button {
                        text: "stretch"
                        width: (parent.width - 20) / 3
                        height: parent.height
                        checked: menuMapAtStart.selectedDisplayMode === "stretch"

                        onClicked: {
                            menuMapAtStart.selectedDisplayMode = "stretch"
                        }
                    }

                    Button {
                        text: "fill"
                        width: (parent.width - 20) / 3
                        height: parent.height
                        checked: menuMapAtStart.selectedDisplayMode === "fill"

                        onClicked: {
                            menuMapAtStart.selectedDisplayMode = "fill"
                        }
                    }

                    Button {
                        text: "tile"
                        width: (parent.width - 20) / 3
                        height: parent.height
                        checked: menuMapAtStart.selectedDisplayMode === "tile"

                        onClicked: {
                            menuMapAtStart.selectedDisplayMode = "tile"
                        }
                    }
                }

                // Background ListView
                ListView {
                    id: listBackGround
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10
                    clip: true

                    model: 3

                    delegate: Rectangle {
                        width: listBackGround.width
                        height: 80
                        radius: 6
                        border.width: menuMapAtStart.selectedBackground === index ? 3 : 1
                        border.color: menuMapAtStart.selectedBackground === index ? "#007BFF" : "#555555"

                        Image {
                            id: bgImage
                            anchors.fill: parent
                            source: "qrc:/assets/tile/water/water_" + (index + 1) + ".jpg"
                            fillMode: Image.PreserveAspectCrop
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                menuMapAtStart.selectedBackground = index
                            }
                        }
                    }
                }
            }
        }

        // Load map content
        Rectangle {
            id: loadMapContent
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            visible: false

            ColumnLayout {
                anchors.fill: parent
                spacing: 10

                // Maps container
                Rectangle {
                    id: mapsContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#333333"
                    radius: 6
                    border.color: "#4A90E2"
                    border.width: 1

                    // Header avec titre
                    Rectangle {
                        id: headerSection
                        width: parent.width
                        height: 40
                        color: "#383838"
                        radius: 6
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            spacing: 10

                            Rectangle {
                                width: 30
                                height: 30
                                radius: 15
                                color: "#4A90E2"
                                opacity: 0.2

                                Text {
                                    anchors.centerIn: parent
                                    text: "🗺️"
                                    font.pixelSize: 16
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Load a map"
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }
                    }

                    // Liste des maps
                    ListView {
                        id: mapsList
                        anchors.top: headerSection.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        model: []
                        spacing: 5
                        clip: true
                        focus: true
                        interactive: true
                        boundsBehavior: Flickable.StopAtBounds

                        Component.onCompleted: {
                            model = MapLoader.getAvailableMaps()
                        }

                        ScrollBar.vertical: ScrollBar {
                            id: scrollBar
                            active: mapsList.contentHeight > mapsList.height
                            policy: ScrollBar.AsNeeded
                            visible: mapsList.contentHeight > mapsList.height
                            interactive: true

                            contentItem: Rectangle {
                                implicitWidth: 8
                                radius: width / 2
                                color: "#999999"
                                opacity: scrollBar.pressed ? 0.8 : 0.5
                            }
                        }

                        delegate: Button {
                            width: mapsList.width
                            height: 40

                            background: Rectangle {
                                anchors.fill: parent
                                color: "#444444"
                                radius: 4
                                border.color: "#4A90E2"
                                border.width: 1
                            }

                            contentItem: Text {
                                text: modelData
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                console.log("Selected map: " + modelData)
                                menuMapAtStart.selectedMap = modelData
                            }
                        }
                    }
                }
            }
        }

        // Bottom action buttons
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            Button {
                text: "Confirmer"
                Layout.fillWidth: true
                onClicked: {
                    if (backgroundContent.visible && menuMapAtStart.selectedBackground !== -1) {
                        // Emit signal to show InfoPanel and hide this popup
                        menuMapAtStart.backgroundSelected(menuMapAtStart.selectedBackground, menuMapAtStart.selectedDisplayMode)
                        menuMapAtStart.visible = false
                    }
                    else if (loadMapContent.visible && menuMapAtStart.selectedMap !== "") {
                        console.log("Loading map: " + menuMapAtStart.selectedMap)
                        if (typeof logic !== 'undefined') {
                            logic.removeCurrentMap()
                            MapLoader.loadMap(menuMapAtStart.selectedMap)
                        }
                        menuMapAtStart.visible = false
                    }
                }
            }

            Button {
                text: "Annuler"
                Layout.fillWidth: true
                onClicked: {
                    menuMapAtStart.visible = false
                }
            }
        }
    }

    Component.onCompleted: {
        visible = true
    }
}
