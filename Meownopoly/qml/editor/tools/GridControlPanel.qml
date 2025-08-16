import QtQuick 2.15
import QtQuick.Controls

Item {
    id: gridControlPanel

    // Référence vers le GridManager
    property var gridManager: null

    // Propriétés pour contrôler la visibilité
    property bool showControlPanel: true
    property bool showInfoPanel: true


    // Panneau de contrôle principal
    Rectangle {
        id: controlPanel
        width: 180
        height: implicitHeight
        color: "#e0e0e0"
        border.color: "#999999"
        border.width: 1
        radius: 5
        visible: showControlPanel

        anchors {
            top: parent.top
            right: parent.right
            margins: 10
        }

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Text {
                text: "Contrôles de grille"
                font.bold: true
                font.pixelSize: 12
            }

            Row {
                spacing: 8
                Text {
                    text: "Taille:"
                    anchors.verticalCenter: parent.verticalCenter
                }
                SpinBox {
                    from: 1
                    to: 1000
                    stepSize: 5
                    height : 35
                    value: gridManager ? gridManager.gridSize : 20
                    onValueChanged: {
                        if (gridManager) {
                            gridManager.gridSize = value
                        }
                    }
                }
            }

            Row {
                spacing: 8
                CheckBox {
                    id: showGridCheckBox
                    checked: gridManager ? gridManager.showGrid : true
                    onCheckedChanged: {
                        if (gridManager) {
                            gridManager.showGrid = checked
                        }
                    }
                }
                Text {
                    text: "Afficher grille"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                spacing: 8
                CheckBox {
                    id: snapGridCheckBox
                    checked: gridManager ? gridManager.snapToGrid : true
                    onCheckedChanged: {
                        if (gridManager) {
                            gridManager.snapToGrid = checked
                        }
                    }
                }
                Text {
                    text: "Snap à la grille"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Button {
                id: editMod
                text: isEdit ? "Mode Édition" : "Mode Lecture"
                font.bold: true
                width: parent.width
                height: 35
                onClicked: isEdit = !isEdit
            }
            Button {
                text: "Choisir éléments"
                font.bold: true
                width: parent.width
                height: 35
                enabled: isEdit
                visible : enabled
                onClicked: {
                    selectDecorationPopup.open()
                }
            }
        }
    }

    GridControlPopupAsset {
        id: selectDecorationPopup
        anchors.centerIn: parent
        focus: true
        height: 300
        width: 400
        modal: true
    }

    // Panneau d'informations en bas à gauche
    Rectangle {
        id: infoPanel
        width: infoText.width + 20
        height: infoText.height + 16
        color: "#f0f0f0"
        border.color: "#cccccc"
        border.width: 1
        radius: 3
        visible: showInfoPanel

        anchors {
            bottom: parent.bottom
            left: parent.left
            margins: 10
        }

        Text {
            id: infoText
            anchors.centerIn: parent
            text: gridManager ?
                      ("Grille: " + gridManager.gridSize + "px | Snap: " + (gridManager.snapToGrid ? "ON" : "OFF") +
                       " | Visible: " + (gridManager.showGrid ? "ON" : "OFF")) :
                      "Grille: N/A"
            color: "black"
            font.pixelSize: 10
        }
    }

    // Bouton pour masquer/afficher le panneau de contrôle
    Rectangle {
        id: toggleButton
        width: 24
        height: 24
        color: "#d0d0d0"
        border.color: "#999999"
        border.width: 1
        radius: 3

        anchors {
            top: parent.top
            right: showControlPanel ? controlPanel.left : parent.right
            margins: 10
        }

        Text {
            anchors.centerIn: parent
            text: showControlPanel ? "◀" : "▶"
            font.pixelSize: 12
            color: "#333333"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                showControlPanel = !showControlPanel
            }
        }
    }

    // Fonctions utiles
    function toggleControlPanel() {
        showControlPanel = !showControlPanel
    }

    function toggleInfoPanel() {
        showInfoPanel = !showInfoPanel
    }

    function hideAll() {
        showControlPanel = false
        showInfoPanel = false
    }

    function showAll() {
        showControlPanel = true
        showInfoPanel = true
    }
}
