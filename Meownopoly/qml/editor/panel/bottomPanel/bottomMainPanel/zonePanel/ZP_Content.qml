import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import EditorEnum

import "../"
import editorBottomPanel
import "../../bottomSidePanel/zoneConfigPanel/"

/**
 * Panneau moderne pour gérer les zones d'exclusion et les zones d'effet
 */
EBP_Content {
    id: root

    required property var logic

    // Propriétés internes pour gérer l'état de l'interface
    property string currentZoneType: "exclusion"
    property bool isDrawModeActive: logic && logic.editorMouseMode === EditorEnum.EM_DRAW_POLYGON

    // Fonction pour changer le type de zone
    function switchZoneType(zoneType) {
        root.currentZoneType = zoneType
        if (zoneType === "exclusion") {
            colorPicker.selectedColor = "#FF5722"
        } else {
            colorPicker.selectedColor = "#3F51B5"
        }
        updateBackendConfiguration()
        // Synchroniser le sélecteur de direction
        syncDirectionPicker()
    }

    // Fonction pour synchroniser le sélecteur vectoriel avec les champs texte
    function syncDirectionPicker() {
        if (root.currentZoneType === "effect") {
            var x = parseFloat(velXInput.text) || 0
            var y = parseFloat(velYInput.text) || 0
            directionPicker.setDirection(x, y)
        }
    }

    // Signaux
    signal drawModeActivated()
    signal drawModeDeactivated()

    sidePanelRatio: 0

    // Arrière-plan avec dégradé subtil
    Rectangle {
        anchors.fill: parent
        color: "#1a1a1a"
    }

    ScrollView {
        id: mainContent
        anchors.fill: parent
        anchors.margins: 10
        clip: true
        contentWidth: mainLayout.width

        RowLayout {
            id: mainLayout
            height: mainContent.height - 20
            spacing: 10

            // ==================== COLONNE 1: TYPE DE ZONE ====================
            ColumnLayout {
                Layout.preferredWidth: 110
                Layout.fillHeight: true
                spacing: 8

                Text {
                    text: "Type"
                    font.pointSize: 9
                    font.bold: true
                    color: "#ffffff"
                    Layout.alignment: Qt.AlignHCenter
                }

                // Type de zone
                Rectangle {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: Screen.pixelDensity * 20
                    Layout.alignment: Qt.AlignHCenter
                    radius: 6
                    color: root.currentZoneType === "exclusion" ? "#8B0000" : "#2a2a2a"
                    border.color: root.currentZoneType === "exclusion" ? "#FF6B6B" : "#3a3a3a"
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        Text {
                            text: "🚫"
                            font.pointSize: 16
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "Exclusion"
                            font.pointSize: 8
                            font.bold: true
                            color: "#ffffff"
                            Layout.alignment: Qt.AlignHCenter
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.switchZoneType("exclusion")
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: Screen.pixelDensity * 20
                    Layout.alignment: Qt.AlignHCenter
                    radius: 6
                    color: root.currentZoneType === "effect" ? "#1B4F72" : "#2a2a2a"
                    border.color: root.currentZoneType === "effect" ? "#5DADE2" : "#3a3a3a"
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        Text {
                            text: "⚡"
                            font.pointSize: 16
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "Effet"
                            font.pointSize: 8
                            font.bold: true
                            color: "#ffffff"
                            Layout.alignment: Qt.AlignHCenter
                        }

                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.switchZoneType("effect")
                    }
                }
            }

            // Séparateur vertical
            Rectangle {
                Layout.fillHeight: true
                width: 1
                color: "#3a3a3a"
            }

            // ==================== COLONNE 2: NOM + COULEURS ====================
            ColumnLayout {
                Layout.preferredWidth: 250
                Layout.fillHeight: true
                spacing: 8

                Text {
                    text: "Nom & Couleur"
                    font.pointSize: 9
                    font.bold: true
                    color: "#ffffff"
                    Layout.alignment: Qt.AlignHCenter
                }

                // Nom de la zone (toujours visible)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "📝"
                        font.pointSize: 12
                        color: "#b0b0b0"
                    }

                    TextField {
                        id: nameInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        placeholderText: "Nom de la zone..."
                        placeholderTextColor: "#666666"
                        selectByMouse: true
                        font.pointSize: 9

                        background: Rectangle {
                            radius: 6
                            color: "#2a2a2a"
                            border.color: nameInput.activeFocus ? "#5DADE2" : "#3a3a3a"
                            border.width: 2
                        }

                        color: "#ffffff"
                        onEditingFinished: {
                            updateBackendConfiguration()
                            syncDirectionPicker()
                        }
                    }
                }

                // Aperçu couleur + Palette
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    // Aperçu de la couleur sélectionnée
                    ColumnLayout {
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 50
                        spacing: 6

                        Text {
                            text: "Aperçu"
                            font.pointSize: 7
                            color: "#b0b0b0"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8
                            color: colorPicker.selectedColor
                            border.color: Qt.lighter(colorPicker.selectedColor, 1.5)
                            border.width: 2

                            Text {
                                anchors.centerIn: parent
                                text: colorPicker.selectedColor.toUpperCase()
                                font.pointSize: 7
                                font.bold: true
                                color: "#ffffff"
                                style: Text.Outline
                                styleColor: "#000000"
                                wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    // Grille de couleurs
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6

                        Text {
                            text: "🎨 Palette"
                            font.pointSize: 7
                            color: "#b0b0b0"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Grid {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            columns: 6
                            spacing: 4

                            Repeater {
                                model: ["#FF5722", "#E91E63", "#9C27B0", "#673AB7",
                                        "#3F51B5", "#2196F3", "#00BCD4", "#009688",
                                        "#4CAF50", "#8BC34A", "#FFEB3B", "#FF9800"]

                                Rectangle {
                                    width: (parent.width - 20) / 6
                                    height: width
                                    radius: 6
                                    color: modelData
                                    border.color: colorPicker.selectedColor === modelData ? "#ffffff" : "transparent"
                                    border.width: 2

                                    Behavior on border.color { ColorAnimation { duration: 100 } }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true

                                        onEntered: parent.scale = 1.1
                                        onExited: parent.scale = 1.0
                                        onClicked: {
                                            colorPicker.selectedColor = modelData
                                            updateBackendConfiguration()
                                        }
                                    }

                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                }
                            }
                        }
                    }
                }
            }

            // Séparateur vertical
            Rectangle {
                Layout.fillHeight: true
                width: 1
                color: "#3a3a3a"
            }

            // ==================== COLONNE 3: PARAMÈTRES (EFFET UNIQUEMENT) ====================
            ColumnLayout {
                Layout.preferredWidth: 280
                Layout.fillHeight: true
                spacing: 8
                visible: root.currentZoneType === "effect"

                Text {
                    text: "⚙️ Paramètres"
                    font.pointSize: 9
                    font.bold: true
                    color: "#ffffff"
                    Layout.alignment: Qt.AlignHCenter
                }

                // Vélocité
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "💨 Vélocité:"
                        color: "#b0b0b0"
                        font.pointSize: 8
                        Layout.preferredWidth: 70
                    }

                    TextField {
                        id: velXInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        placeholderText: "X"
                        placeholderTextColor: "#666666"
                        validator: DoubleValidator { }
                        font.pointSize: 8
                        horizontalAlignment: Text.AlignHCenter

                        background: Rectangle {
                            radius: 4
                            color: "#2a2a2a"
                            border.color: velXInput.activeFocus ? "#5DADE2" : "#3a3a3a"
                            border.width: 1
                        }

                        color: "#ffffff"
                        onEditingFinished: {
                            updateBackendConfiguration()
                            syncDirectionPicker()
                        }
                    }

                    TextField {
                        id: velYInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        placeholderText: "Y"
                        placeholderTextColor: "#666666"
                        validator: DoubleValidator { }
                        font.pointSize: 8
                        horizontalAlignment: Text.AlignHCenter

                        background: Rectangle {
                            radius: 4
                            color: "#2a2a2a"
                            border.color: velYInput.activeFocus ? "#5DADE2" : "#3a3a3a"
                            border.width: 1
                        }

                        color: "#ffffff"
                        onEditingFinished: {
                            updateBackendConfiguration()
                            syncDirectionPicker()
                        }
                    }

                    TextField {
                        id: velStrengthInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        placeholderText: "Force"
                        placeholderTextColor: "#666666"
                        validator: DoubleValidator { bottom: 0 }
                        font.pointSize: 8
                        horizontalAlignment: Text.AlignHCenter

                        background: Rectangle {
                            radius: 4
                            color: "#2a2a2a"
                            border.color: velStrengthInput.activeFocus ? "#5DADE2" : "#3a3a3a"
                            border.width: 1
                        }

                        color: "#ffffff"
                        onEditingFinished: {
                            updateBackendConfiguration()
                            syncDirectionPicker()
                        }
                    }
                }

                // Friction
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "🧊 Friction:"
                        color: "#b0b0b0"
                        font.pointSize: 8
                        Layout.preferredWidth: 70
                    }

                    Slider {
                        id: frictionSlider
                        Layout.fillWidth: true
                        from: 0.0
                        to: 1.0
                        value: 0.0
                        stepSize: 0.01

                        background: Rectangle {
                            x: frictionSlider.leftPadding
                            y: frictionSlider.topPadding + frictionSlider.availableHeight / 2 - height / 2
                            implicitWidth: 100
                            implicitHeight: 4
                            width: frictionSlider.availableWidth
                            height: implicitHeight
                            radius: 2
                            color: "#3a3a3a"

                            Rectangle {
                                width: frictionSlider.visualPosition * parent.width
                                height: parent.height
                                color: "#5DADE2"
                                radius: 2
                            }
                        }

                        handle: Rectangle {
                            x: frictionSlider.leftPadding + frictionSlider.visualPosition * (frictionSlider.availableWidth - width)
                            y: frictionSlider.topPadding + frictionSlider.availableHeight / 2 - height / 2
                            implicitWidth: 14
                            implicitHeight: 14
                            radius: 7
                            color: "#ffffff"
                            border.color: "#5DADE2"
                            border.width: 2
                        }

                        onMoved: updateBackendConfiguration()
                    }

                    Rectangle {
                        Layout.preferredWidth: 45
                        height: 26
                        radius: 4
                        color: "#2a2a2a"
                        border.color: "#5DADE2"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: frictionSlider.value.toFixed(2)
                            color: "#ffffff"
                            font.pointSize: 8
                            font.bold: true
                        }
                    }
                }

                // Multiplicateur Vitesse
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "🏃 Mult. Vit:"
                        color: "#b0b0b0"
                        font.pointSize: 8
                        Layout.preferredWidth: 70
                    }

                    Slider {
                        id: speedMultSlider
                        Layout.fillWidth: true
                        from: 0.1
                        to: 3.0
                        value: 1.0
                        stepSize: 0.1

                        background: Rectangle {
                            x: speedMultSlider.leftPadding
                            y: speedMultSlider.topPadding + speedMultSlider.availableHeight / 2 - height / 2
                            implicitWidth: 100
                            implicitHeight: 4
                            width: speedMultSlider.availableWidth
                            height: implicitHeight
                            radius: 2
                            color: "#3a3a3a"

                            Rectangle {
                                width: speedMultSlider.visualPosition * parent.width
                                height: parent.height
                                color: "#4CAF50"
                                radius: 2
                            }
                        }

                        handle: Rectangle {
                            x: speedMultSlider.leftPadding + speedMultSlider.visualPosition * (speedMultSlider.availableWidth - width)
                            y: speedMultSlider.topPadding + speedMultSlider.availableHeight / 2 - height / 2
                            implicitWidth: 14
                            implicitHeight: 14
                            radius: 7
                            color: "#ffffff"
                            border.color: "#4CAF50"
                            border.width: 2
                        }

                        onMoved: updateBackendConfiguration()
                    }

                    Rectangle {
                        Layout.preferredWidth: 45
                        height: 26
                        radius: 4
                        color: "#2a2a2a"
                        border.color: "#4CAF50"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "×" + speedMultSlider.value.toFixed(1)
                            color: "#ffffff"
                            font.pointSize: 8
                            font.bold: true
                        }
                    }
                }

                // Multiplicateur Accélération
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "⚡ Mult. Acc:"
                        color: "#b0b0b0"
                        font.pointSize: 8
                        Layout.preferredWidth: 70
                    }

                    Slider {
                        id: accelMultSlider
                        Layout.fillWidth: true
                        from: 0.0
                        to: 10.0
                        value: 1.0
                        stepSize: 0.05

                        background: Rectangle {
                            x: accelMultSlider.leftPadding
                            y: accelMultSlider.topPadding + accelMultSlider.availableHeight / 2 - height / 2
                            implicitWidth: 100
                            implicitHeight: 4
                            width: accelMultSlider.availableWidth
                            height: implicitHeight
                            radius: 2
                            color: "#3a3a3a"

                            Rectangle {
                                width: accelMultSlider.visualPosition * parent.width
                                height: parent.height
                                color: "#FF9800"
                                radius: 2
                            }
                        }

                        handle: Rectangle {
                            x: accelMultSlider.leftPadding + accelMultSlider.visualPosition * (accelMultSlider.availableWidth - width)
                            y: accelMultSlider.topPadding + accelMultSlider.availableHeight / 2 - height / 2
                            implicitWidth: 14
                            implicitHeight: 14
                            radius: 7
                            color: "#ffffff"
                            border.color: "#FF9800"
                            border.width: 2
                        }

                        onMoved: updateBackendConfiguration()
                    }

                    Rectangle {
                        Layout.preferredWidth: 45
                        height: 26
                        radius: 4
                        color: "#2a2a2a"
                        border.color: "#FF9800"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "×" + accelMultSlider.value.toFixed(2)
                            color: "#ffffff"
                            font.pointSize: 8
                            font.bold: true
                        }
                    }
                }
            }

            // Séparateur vertical (visible seulement si paramètres visibles)
            Rectangle {
                Layout.fillHeight: true
                width: 1
                color: "#3a3a3a"
                visible: root.currentZoneType === "effect"
            }

            // ==================== COLONNE 4: SÉLECTEUR DE DIRECTION ====================
            ColumnLayout {
                Layout.preferredWidth: 200
                Layout.fillHeight: true
                spacing: 8
                visible: root.currentZoneType === "effect"

                Text {
                    text: "Direction"
                    font.pointSize: 9
                    font.bold: true
                    color: "#ffffff"
                    Layout.alignment: Qt.AlignHCenter
                }

                // Sélecteur de direction vectorielle
                ZCP_VectorDirectionPicker {
                    id: directionPicker
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignHCenter

                    backgroundColor: "#1a1a1a"
                    circleColor: "#333333"
                    arrowColor: "#5DADE2"
                    gridColor: "#444444"
                    highlightColor: "#7bd97f"
                    circleSize: 140

                    onDirectionChanged: function(x, y) {
                        velXInput.text = x.toFixed(2)
                        velYInput.text = y.toFixed(2)
                        updateBackendConfiguration()
                    }

                    Component.onCompleted: {
                        // Synchroniser au démarrage
                        root.syncDirectionPicker()
                    }
                }

            }

            // Séparateur vertical
            Rectangle {
                Layout.fillHeight: true
                width: 1
                color: "#3a3a3a"
                visible: root.currentZoneType === "effect"
            }

            // ==================== COLONNE 5: BOUTON DESSINER + INSTRUCTIONS ====================
            ColumnLayout {
                Layout.preferredWidth: 140
                Layout.fillHeight: true
                spacing: 8

                Text {
                    text: "Action"
                    font.pointSize: 9
                    font.bold: true
                    color: "#ffffff"
                    Layout.alignment: Qt.AlignHCenter
                }

                // Bouton Dessiner
                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 70
                    Layout.alignment: Qt.AlignHCenter
                    radius: 8
                    color: root.isDrawModeActive ? "#8B0000" : colorPicker.selectedColor
                    border.color: Qt.lighter(colorPicker.selectedColor, 1.5)
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: 200 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: root.isDrawModeActive ? "❌" : "✏️"
                            font.pointSize: 20
                        }

                        Text {
                            text: root.isDrawModeActive ? "Annuler" : "Dessiner"
                            font.pointSize: 10
                            font.bold: true
                            color: "#ffffff"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onEntered: parent.scale = 1.05
                        onExited: parent.scale = 1.0

                        onClicked: {
                            if (root.isDrawModeActive) {
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

                    Behavior on scale { NumberAnimation { duration: 100 } }
                }

                // Instructions
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 6
                    color: "#2a2a2a"
                    border.color: root.isDrawModeActive ? "#FFEB3B" : "#3a3a3a"
                    border.width: root.isDrawModeActive ? 2 : 1
                    visible: root.isDrawModeActive

                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Text {
                            text: "📌 Instructions"
                            font.pointSize: 9
                            font.bold: true
                            color: "#FFEB3B"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Repeater {
                                model: [
                                    { icon: "🖱️", text: "Clic gauche: Point" },
                                    { icon: "🖱️", text: "Clic droit: Finir" },
                                    { icon: "⌨️", text: "Échap: Annuler" }
                                ]

                                RowLayout {
                                    spacing: 4

                                    Text {
                                        text: modelData.icon
                                        font.pointSize: 10
                                    }

                                    Text {
                                        text: modelData.text
                                        font.pointSize: 7
                                        color: "#b0b0b0"
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                Item { Layout.fillHeight: true; visible: !root.isDrawModeActive }
            }
        }
    }

    // ==================== DONNÉES ====================
    QtObject {
        id: colorPicker
        property string selectedColor: "#FF5722"
    }

    // ==================== FONCTIONS ====================
    function updateBackendConfiguration() {
        if (logic && logic.mouseLogic) {
            if (logic.mouseLogic.setZoneColor) {
                logic.mouseLogic.setZoneColor(colorPicker.selectedColor)
            }

            if (logic.mouseLogic.setZoneProperties) {
                logic.mouseLogic.setZoneProperties({
                    name: nameInput.text,
                    exclusion: (root.currentZoneType === "exclusion"),
                    velocityX: parseFloat(velXInput.text) || 0,
                    velocityY: parseFloat(velYInput.text) || 0,
                    velocityStrength: parseFloat(velStrengthInput.text) || 0,
                    frictionStrength: frictionSlider.value,
                    speedMultiplier: speedMultSlider.value,
                    accelerationMultiplier: accelMultSlider.value
                })
            }
        }
    }
}
