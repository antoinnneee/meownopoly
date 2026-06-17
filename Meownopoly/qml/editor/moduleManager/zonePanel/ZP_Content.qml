import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import EditorEnum

import "../"
import editorBottomPanel
import zoneConfigPanel
import theme
import ui_item

/**
 * Panneau moderne pour gérer les zones d'exclusion et les zones d'effet
 */
EBP_Content {
    id: root

    required property var logic

    // Propriétés internes pour gérer l'état de l'interface
    property string currentZoneType: "exclusion"
    property bool isDrawModeActive: logic && logic.editorMouseMode === EditorEnum.EM_DRAW_POLYGON
    property bool isGridSnapActive: logic && logic.mouseLogic && logic.mouseLogic.shiftPressed || false

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
    signal focusReleased()

    sidePanelRatio: 0

    // Arrière-plan avec dégradé subtil
    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    ScrollView {
        id: mainContent
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        clip: true
        contentWidth: mainLayout.width

        RowLayout {
            id: mainLayout
            height: mainContent.height - 20
            spacing: Theme.spacingL

            // ==================== COLONNE 1: TYPE DE ZONE ====================
            ColumnLayout {
                Layout.preferredWidth: 110
                Layout.fillHeight: true
                spacing: Theme.spacingM

                Text {
                    text: "Type"
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignHCenter
                }

                // Type de zone
                Rectangle {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: Screen.pixelDensity * 20
                    Layout.alignment: Qt.AlignHCenter
                    radius: Theme.radiusM
                    color: root.currentZoneType === "exclusion" ? "#8B0000" : Theme.surface
                    border.color: root.currentZoneType === "exclusion" ? "#FF6B6B" : Theme.surfaceHover
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
                    Behavior on border.color { ColorAnimation { duration: Theme.durationNormal } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingXS

                        Text {
                            text: "🚫"
                            font.pixelSize: Theme.fontSizeHeading
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "Exclusion"
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            color: Theme.textPrimary
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
                    radius: Theme.radiusM
                    color: root.currentZoneType === "effect" ? "#1B4F72" : Theme.surface
                    border.color: root.currentZoneType === "effect" ? "#5DADE2" : Theme.surfaceHover
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
                    Behavior on border.color { ColorAnimation { duration: Theme.durationNormal } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingXS

                        Text {
                            text: "⚡"
                            font.pixelSize: Theme.fontSizeHeading
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "Effet"
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            color: Theme.textPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }

                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.switchZoneType("effect")
                    }
                }

                // Espaceur pour pousser vers le haut
                Item {
                    Layout.fillHeight: true
                }
            }

            // Séparateur vertical
            Rectangle {
                Layout.fillHeight: true
                width: 1
                color: Theme.surfaceHover
            }

            // ==================== COLONNE 2: NOM + COULEURS ====================
            ColumnLayout {
                Layout.preferredWidth: 250
                Layout.fillHeight: true
                spacing: Theme.spacingM

                Text {
                    text: "Nom & Couleur"
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignHCenter
                }

                // Nom de la zone (toujours visible)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingS

                    Text {
                        text: "📝"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.textSecondary
                    }

                    TextField {
                        id: nameInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        placeholderText: "Nom de la zone..."
                        placeholderTextColor: Theme.textDisabled
                        selectByMouse: true
                        font.pixelSize: Theme.fontSizeBody

                        background: Rectangle {
                            radius: Theme.radiusM
                            color: Theme.surface
                            border.color: nameInput.activeFocus ? Theme.hover(Theme.accent) : Theme.surfaceHover
                            border.width: 2
                        }

                        color: Theme.textPrimary
                        onEditingFinished: {
                            updateBackendConfiguration()
                            syncDirectionPicker()
                        }
                        Keys.onReturnPressed: {
                            focus = false
                            root.focusReleased()
                        }
                    }
                }

                // Aperçu couleur + Palette
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingXL

                    // Aperçu de la couleur sélectionnée
                    ColumnLayout {
                        Layout.preferredWidth: 60
                        spacing: Theme.spacingS

                        Text {
                            text: "Aperçu"
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.textSecondary
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: colorPaletteGrid.height
                            radius: Theme.radiusL
                            color: colorPicker.selectedColor
                            border.color: Qt.lighter(colorPicker.selectedColor, 1.5)
                            border.width: 2

                            Text {
                                anchors.centerIn: parent
                                text: colorPicker.selectedColor.toUpperCase()
                                font.pixelSize: Theme.fontSizeTiny
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
                        spacing: Theme.spacingS

                        Text {
                            text: "🎨 Palette"
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.textSecondary
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Grid {
                            id: colorPaletteGrid
                            Layout.fillWidth: true
                            columns: 6
                            spacing: Theme.spacingXS

                            Repeater {
                                model: ["#FF5722", "#E91E63", "#9C27B0", "#673AB7",
                                        "#3F51B5", "#2196F3", "#00BCD4", "#009688",
                                        "#4CAF50", "#8BC34A", "#FFEB3B", "#FF9800"]

                                Rectangle {
                                    width: (parent.width - 20) / 6
                                    height: width
                                    radius: Theme.radiusM
                                    color: modelData
                                    border.color: colorPicker.selectedColor === modelData ? "#ffffff" : "transparent"
                                    border.width: 2

                                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

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

                                    Behavior on scale { NumberAnimation { duration: Theme.durationFast } }
                                }
                            }
                        }
                    }
                }

                // Espaceur pour pousser tout vers le haut et éviter l'étirement
                Item {
                    Layout.fillHeight: true
                }
            }

            // Séparateur vertical
            Rectangle {
                Layout.fillHeight: true
                width: 1
                color: Theme.surfaceHover
            }

            // ==================== COLONNE 3: PARAMÈTRES (EFFET UNIQUEMENT) ====================
            ColumnLayout {
                Layout.preferredWidth: 280
                Layout.fillHeight: true
                spacing: Theme.spacingM
                visible: root.currentZoneType === "effect"

                Text {
                    text: "⚙️ Paramètres"
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignHCenter
                }

                // Vélocité
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingS

                    Text {
                        text: "💨 Vélocité:"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        Layout.preferredWidth: 70
                    }

                    TextField {
                        id: velXInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        placeholderText: "X"
                        placeholderTextColor: Theme.textDisabled
                        validator: DoubleValidator { }
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter

                        background: Rectangle {
                            radius: Theme.radiusS
                            color: Theme.surface
                            border.color: velXInput.activeFocus ? Theme.hover(Theme.accent) : Theme.surfaceHover
                            border.width: 1
                        }

                        color: Theme.textPrimary
                        onEditingFinished: {
                            updateBackendConfiguration()
                            syncDirectionPicker()
                        }
                        Keys.onReturnPressed: {
                            focus = false
                            root.focusReleased()
                        }
                    }

                    TextField {
                        id: velYInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        placeholderText: "Y"
                        placeholderTextColor: Theme.textDisabled
                        validator: DoubleValidator { }
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter

                        background: Rectangle {
                            radius: Theme.radiusS
                            color: Theme.surface
                            border.color: velYInput.activeFocus ? Theme.hover(Theme.accent) : Theme.surfaceHover
                            border.width: 1
                        }

                        color: Theme.textPrimary
                        onEditingFinished: {
                            updateBackendConfiguration()
                            syncDirectionPicker()
                        }
                        Keys.onReturnPressed: {
                            focus = false
                            root.focusReleased()
                        }
                    }

                    TextField {
                        id: velStrengthInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        placeholderText: "Force"
                        placeholderTextColor: Theme.textDisabled
                        validator: DoubleValidator { bottom: 0 }
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter

                        background: Rectangle {
                            radius: Theme.radiusS
                            color: Theme.surface
                            border.color: velStrengthInput.activeFocus ? Theme.hover(Theme.accent) : Theme.surfaceHover
                            border.width: 1
                        }

                        color: Theme.textPrimary
                        onEditingFinished: {
                            updateBackendConfiguration()
                            syncDirectionPicker()
                        }
                        Keys.onReturnPressed: {
                            focus = false
                            root.focusReleased()
                        }
                    }
                }

                // Friction
                MeowSlider {
                    id: frictionSlider
                    Layout.fillWidth: true
                    label: "🧊 Friction:"
                    labelWidth: 70
                    labelBold: false
                    from: 0.0
                    to: 1.0
                    value: 0.0
                    stepSize: 0.01
                    decimals: 2
                    accentColor: Theme.hover(Theme.accent)
                    onMoved: updateBackendConfiguration()
                }

                // Multiplicateur Vitesse
                MeowSlider {
                    id: speedMultSlider
                    Layout.fillWidth: true
                    label: "🏃 Mult. Vit:"
                    labelWidth: 70
                    labelBold: false
                    from: 0.1
                    to: 3.0
                    value: 1.0
                    stepSize: 0.1
                    decimals: 1
                    unitText: "×"
                    accentColor: Theme.success
                    onMoved: updateBackendConfiguration()
                }

                // Multiplicateur Accélération
                MeowSlider {
                    id: accelMultSlider
                    Layout.fillWidth: true
                    label: "⚡ Mult. Acc:"
                    labelWidth: 70
                    labelBold: false
                    from: 0.0
                    to: 10.0
                    value: 1.0
                    stepSize: 0.05
                    decimals: 2
                    unitText: "×"
                    accentColor: Theme.warning
                    onMoved: updateBackendConfiguration()
                }

                // Espaceur pour pousser vers le haut
                Item {
                    Layout.fillHeight: true
                }
            }

            // Séparateur vertical (visible seulement si paramètres visibles)
            Rectangle {
                Layout.fillHeight: true
                width: 1
                color: Theme.surfaceHover
                visible: root.currentZoneType === "effect"
            }

            // ==================== COLONNE 4: SÉLECTEUR DE DIRECTION ====================
            ColumnLayout {
                Layout.preferredWidth: 200
                Layout.fillHeight: true
                spacing: Theme.spacingM
                visible: root.currentZoneType === "effect"

                Text {
                    text: "Direction"
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignHCenter
                }

                // Sélecteur de direction vectorielle
                ZCP_VectorDirectionPicker {
                    id: directionPicker
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignHCenter

                    backgroundColor: Theme.background
                    circleColor: Theme.surfaceAlt
                    arrowColor: Theme.hover(Theme.accent)
                    gridColor: Theme.border
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
                color: Theme.surfaceHover
                visible: root.currentZoneType === "effect"
            }

            // ==================== COLONNE 5: BOUTON DESSINER + INSTRUCTIONS ====================
            ColumnLayout {
                Layout.preferredWidth: 140
                Layout.fillHeight: true
                spacing: Theme.spacingM

                Text {
                    text: "Action"
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignHCenter
                }

                // Bouton Dessiner
                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 70
                    Layout.alignment: Qt.AlignHCenter
                    radius: Theme.radiusL
                    color: root.isDrawModeActive ? "#8B0000" : colorPicker.selectedColor
                    border.color: Qt.lighter(colorPicker.selectedColor, 1.5)
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: 200 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        Text {
                            text: root.isDrawModeActive ? "❌" : "✏️"
                            font.pixelSize: Theme.fontSizeDisplay
                        }

                        Text {
                            text: root.isDrawModeActive ? "Annuler" : "Dessiner"
                            font.pixelSize: Theme.fontSizeBody
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

                    Behavior on scale { NumberAnimation { duration: Theme.durationFast } }
                }

                // Instructions
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusM
                    color: Theme.surface
                    border.color: root.isDrawModeActive ? "#FFEB3B" : Theme.surfaceHover
                    border.width: root.isDrawModeActive ? 2 : 1
                    visible: root.isDrawModeActive

                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingM

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            Text {
                                text: "📌 Instructions"
                                font.pixelSize: Theme.fontSizeBody
                                font.bold: true
                                color: "#FFEB3B"
                            }

                            // Badge indicateur d'alignement sur la grille
                            Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 18
                                radius: Theme.radiusS
                                color: root.isGridSnapActive ? Theme.success : Theme.borderLight
                                border.color: root.isGridSnapActive ? "#7bd97f" : Theme.textDisabled
                                border.width: 1
                                visible: root.isDrawModeActive

                                Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
                                Behavior on border.color { ColorAnimation { duration: Theme.durationNormal } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXXS

                                    Text {
                                        text: "⊞"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: root.isGridSnapActive ? Theme.textPrimary : Theme.textMuted
                                    }

                                    Text {
                                        text: root.isGridSnapActive ? "ON" : "OFF"
                                        font.pixelSize: Theme.fontSizeTiny
                                        font.bold: true
                                        color: root.isGridSnapActive ? Theme.textPrimary : Theme.textMuted
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingXS

                            Repeater {
                                model: [
                                    { icon: "🖱️", text: "Clic gauche: Point" },
                                    { icon: "🖱️", text: "Clic droit: Finir" },
                                    { icon: "⇧", text: "Shift: Aligner grille" },
                                    { icon: "⌨️", text: "Échap: Annuler" }
                                ]

                                RowLayout {
                                    spacing: Theme.spacingXS

                                    Text {
                                        text: modelData.icon
                                        font.pixelSize: Theme.fontSizeBody
                                    }

                                    Text {
                                        text: modelData.text
                                        font.pixelSize: Theme.fontSizeTiny
                                        color: Theme.textSecondary
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
