import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import EditorEnum

import "../"
import "../editorBottomPanel"

/**
 * Panneau pour gérer les zones d'exclusion et les zones d'effet
 */
EBP_Content {
    id: root

    required property var logic

    // Propriétés internes pour gérer l'état de l'interface
    property string currentZoneType: "exclusion" // "exclusion" ou "effect"
    property string currentEffectType: "slow"    // "slow", "speed", etc.

    // Signal émis quand on active le mode dessin
    signal drawModeActivated()
    signal drawModeDeactivated()

    // Propriété pour suivre si le mode dessin est actif
    property bool isDrawModeActive: logic && logic.editorMouseMode === EditorEnum.EM_DRAW_POLYGON

    sidePanelRatio: 0

    ScrollView {
        id: mainContent
        anchors.fill: parent
        anchors.margins: 10
        clip: true
        contentHeight: contentLayout.height

        // Layout horizontal principal avec 2 colonnes
        RowLayout {
            id: contentLayout
            width: mainContent.width - 20
            spacing: 20

            // ==================== COLONNE GAUCHE ====================
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width / 2
                Layout.alignment: Qt.AlignTop
                spacing: 10

                // --- En-tête ---
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: "Gestion des Zones"
                        font.pointSize: 13
                        font.bold: true
                        color: "white"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: root.currentZoneType === "exclusion"
                              ? "Les zones d'exclusion empêchent l'accès à certaines parties du plateau."
                              : "Les zones d'effet appliquent des bonus ou malus aux unités à l'intérieur."
                        font.pointSize: 8
                        color: "#aaaaaa"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // Séparateur
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#444444"
                }

                // --- Type de zone ---
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Type de zone"
                        color: "white"
                        font.pointSize: 10
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        RadioButton {
                            id: exclusionRadio
                            text: "Zone d'exclusion"
                            checked: true

                            contentItem: Text {
                                text: parent.text
                                font.pointSize: 9
                                color: "white"
                                leftPadding: parent.indicator.width + parent.spacing
                                verticalAlignment: Text.AlignVCenter
                            }

                            onCheckedChanged: {
                                if(checked) {
                                    root.currentZoneType = "exclusion"
                                    colorPicker.selectedColor = "#FF5722"
                                    updateBackendConfiguration()
                                }
                            }
                        }

                        RadioButton {
                            id: effectRadio
                            text: "Zone d'effet"

                            contentItem: Text {
                                text: parent.text
                                font.pointSize: 9
                                color: "white"
                                leftPadding: parent.indicator.width + parent.spacing
                                verticalAlignment: Text.AlignVCenter
                            }

                            onCheckedChanged: {
                                if(checked) {
                                    root.currentZoneType = "effect"
                                    updateColorForEffect(effectCombo.currentValue)
                                    updateBackendConfiguration()
                                }
                            }
                        }
                    }
                }

                // Séparateur
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#444444"
                }

                // --- Sélection de l'effet ---
                ColumnLayout {
                    id: effectSection
                    Layout.fillWidth: true
                    visible: root.currentZoneType === "effect"
                    spacing: 6

                    Text {
                        text: "Type d'effet"
                        color: "white"
                        font.pointSize: 10
                        font.bold: true
                    }

                    ComboBox {
                        id: effectCombo
                        Layout.fillWidth: true

                        model: ListModel {
                            ListElement { text: "Vitesse"; value: "speed"; colorCode: "#3498db" }
                            ListElement { text: "Friction "; value: "friction"; colorCode: "#f1c40f" }
                        }

                        textRole: "text"
                        valueRole: "value"

                        contentItem: Text {
                            text: effectCombo.displayText
                            font.pointSize: 9
                            color: "white"
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 10
                        }

                        onActivated: {
                            root.currentEffectType = currentValue
                            updateColorForEffect(currentValue)
                            updateBackendConfiguration()
                        }
                    }
                }

                // Spacer pour pousser le contenu vers le haut
                Item {
                    Layout.fillHeight: true
                }
            }

            // ==================== COLONNE DROITE ====================
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width / 2
                Layout.alignment: Qt.AlignTop
                spacing: 10

                // --- Bouton Dessiner ---
                Button {
                    id: drawButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50

                    text: root.isDrawModeActive ? "❌ Annuler" : "✏️ Dessiner une zone"

                    background: Rectangle {
                        radius: 8
                        color: root.isDrawModeActive ? "#c0392b" : colorPicker.selectedColor
                        border.color: Qt.lighter(color, 1.2)
                        border.width: 2

                        Behavior on color {
                            ColorAnimation { duration: 200 }
                        }

                        // Effet de survol
                        opacity: drawButton.hovered ? 0.9 : 1.0
                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                    }

                    contentItem: Text {
                        text: drawButton.text
                        font.pointSize: 10
                        font.bold: true
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        if (root.isDrawModeActive) {
                            // Désactiver le mode dessin
                            if (logic && logic.mouseLogic) {
                                logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
                            }
                            root.drawModeDeactivated()
                        } else {

                            if (logic && logic.mouseLogic) {
                                logic.mouseLogic.changeMouseMode(EditorEnum.EM_DRAW_POLYGON)
                            }
                            root.drawModeActivated()
                            updateBackendConfiguration()
                        }
                    }
                }

                // --- Instructions ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: instructionsText.height + 16
                    visible: root.isDrawModeActive
                    color: "#2c3e50"
                    radius: 6
                    border.color: "#ffcc00"
                    border.width: 2

                    Text {
                        id: instructionsText
                        anchors.centerIn: parent
                        width: parent.width - 16
                        text: "• Clic gauche : ajouter un point\n• Clic droit : terminer\n• Échap : annuler"
                        font.pointSize: 8
                        color: "#ffcc00"
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignLeft
                        lineHeight: 1.2
                    }
                }

                // Séparateur
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#444444"
                }

                // --- Palette de couleurs ---
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Couleur de la zone"
                        color: "white"
                        font.pointSize: 11
                        font.bold: true
                    }

                    // Grille de couleurs
                    Grid {
                        Layout.alignment: Qt.AlignHCenter
                        columns: 8
                        spacing: 6

                        Repeater {
                            model: ["#FF5722", "#E91E63", "#9C27B0", "#3F51B5",
                                    "#00BCD4", "#4CAF50", "#FFEB3B", "#FF9800"]

                            Rectangle {
                                width: 30
                                height: 30
                                radius: 15
                                color: modelData
                                border.color: colorPicker.selectedColor === modelData ? "white" : "#555555"
                                border.width: colorPicker.selectedColor === modelData ? 3 : 1

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        colorPicker.selectedColor = modelData
                                        updateBackendConfiguration()
                                    }
                                }

                                // Animation de sélection
                                Behavior on border.width {
                                    NumberAnimation { duration: 150 }
                                }
                            }
                        }
                    }
                }

                // Spacer pour pousser le contenu vers le haut
                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }

    // --- Objet pour stocker la couleur sélectionnée ---
    QtObject {
        id: colorPicker
        property string selectedColor: "#FF5722"
    }

    // --- Fonctions utilitaires ---

    function updateColorForEffect(effectValue) {
        for(var i = 0; i < effectCombo.model.count; i++) {
            if(effectCombo.model.get(i).value === effectValue) {
                colorPicker.selectedColor = effectCombo.model.get(i).colorCode
                break
            }
        }
    }

    function updateBackendConfiguration() {
        if (logic && logic.mouseLogic) {
            // 1. Mettre à jour la couleur visuelle
            if (logic.mouseLogic.setZoneColor) {
                logic.mouseLogic.setZoneColor(colorPicker.selectedColor)
            }

            // 2. Transmettre le type de zone et l'effet
            // NOTE : Vous devrez implémenter une méthode comme setZoneProperties dans votre C++
            /*
            if (logic.mouseLogic.setZoneProperties) {
                var typeInt = (root.currentZoneType === "exclusion") ? 0 : 1
                logic.mouseLogic.setZoneProperties(typeInt, root.currentEffectType)
            }
            */
        }
    }
}
