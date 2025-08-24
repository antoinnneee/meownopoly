import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts

import Game

Item {
    id: gridControlPanel

    // Référence vers le GridManager
    property var gridManager: null

    // Propriétés pour contrôler la visibilité
    property bool showControlPanel: true
    property bool showInfoPanel: true

    // Propriété pour le mode de sélection
    signal selectionModeChanged(bool isActive)
    signal cancelSelectionRequested()


    onCancelSelectionRequested: {
        cancelSelection()
    }

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

        Column{
            id: controlColumn
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Text {
                text: "Contrôles de grille"
                font.bold: true
                font.pixelSize: 12
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
                id: selectionButton
                text: isSelectionActive ? "✓ Mode Sélection" : "Mode Sélection"
                font.bold: true
                width: parent.width
                height: 35
                enabled: isEdit
                visible: enabled
                checkable: true
                checked: isSelectionActive
                onClicked: {
                    isSelectionActive = checked
                    console.log("Mode sélection: " + checked)
                    selectionModeChanged(checked)
                    if (!checked) {
                        cancelSelectionRequested()
                    }
                }
                // Style visuel amélioré
                background: Rectangle {
                    color: selectionButton.checked ? "#3498db" : "#95a5a6"
                    radius: 5
                }
                contentItem: Text {
                    text: selectionButton.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Row{
                spacing: 8
                visible: isEdit
                enabled: visible
                Text {
                    id: planText
                    text: "Plan: " + planSlider.value
                    width: 25
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    id: planSlider
                    from: 1
                    to: 10
                    stepSize: 1
                    value: 5
                    width : controlColumn.width*0.75
                    onValueChanged: {
                        if (gridManager) {
                            gridManager.currentPlan = value
                        }
                    }
                }
            }

            // Sélecteurs de taille d'élément
            Text {
                text: "Dimensions des éléments"
                font.bold: true
                font.pixelSize: 12
                visible: isEdit
                enabled: visible
            }

            // Sélecteur de largeur
            Row {
                spacing: 8
                visible: isEdit
                enabled: visible

                Text {
                    text: "L:"
                    width: 15
                    anchors.verticalCenter: parent.verticalCenter
                }
                SpinBox {
                    id: widthSpinBox
                    from: 1
                    to: 20
                    stepSize: 1
                    value: 1
                    width: 70
                    height: 30
                    onValueChanged: {
                        gridControlPanel.currentWidth = value
                    }
                    Component.onCompleted: gridControlPanel.currentWidth = value
                }
            }

            // Sélecteur de hauteur
            Row {
                spacing: 8
                visible: isEdit
                enabled: visible

                Text {
                    text: "H:"
                    width: 15
                    anchors.verticalCenter: parent.verticalCenter
                }
                SpinBox {
                    id: heightSpinBox
                    from: 1
                    to: 20
                    stepSize: 1
                    value: 1
                    width: 70
                    height: 30
                    onValueChanged: {
                        gridControlPanel.currentHeight = value
                    }
                    Component.onCompleted: gridControlPanel.currentHeight = value
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
