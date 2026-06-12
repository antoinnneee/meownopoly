import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import theme
import MapFileManager

GroupBox {
    id: root
    title: "Général"

    // Properties
    property bool updatingValues: false

    property alias zoneName: nameField.text
    property alias exclusion: exclusionSwitch.checked
    property alias speedMultiplier: speedSlider.value
    property alias accelerationMultiplier: accelerationSlider.value
    property alias frictionStrength: frictionSlider.value
    // Référence vers l'effet visuel déclenché à l'entrée (id de MapInfo.screenEffects,
    // "" = aucun). Pas un alias : piloté par le ComboBox ci-dessous.
    property string screenEffectId: ""

    // Modèle du sélecteur d'effet : "Aucun" + bibliothèque de la carte.
    // L'accès à `mapInfo.screenEffects` capture la dépendance de binding
    // (NOTIFY screenEffectsChanged) pour rafraîchir la liste à chaud.
    readonly property var _effectModel: {
        const arr = [{ name: "Aucun", id: "" }]
        const map = MapFileManager.currentMap
        const mi = map ? map.mapInfo : null
        if (mi) {
            const dep = mi.screenEffects   // capture la dépendance
            const n = mi.screenEffectCount()
            for (let i = 0; i < n; ++i) {
                const e = mi.screenEffectAt(i)
                if (e) arr.push({ name: e.name, id: e.id })
            }
        }
        return arr
    }

    function _indexForEffectId(id) {
        for (let i = 0; i < root._effectModel.length; ++i)
            if (root._effectModel[i].id === id) return i
        return 0
    }

    // Signal
    signal configurationChanged()
    signal focusReleased()

    // Functions
    function updateFromZoneParameter(zoneParam) {
      if (root.updatingValues) return

        // Update sliders from target values
        nameField.text = zoneParam.zoneName
        exclusionSwitch.checked = zoneParam.exclusion
        speedSlider.value = zoneParam.speedMultiplier
        accelerationSlider.value = zoneParam.accelerationMultiplier
        frictionSlider.value = zoneParam.frictionStrenght
        root.screenEffectId = zoneParam.screenEffectId
        effectCombo.currentIndex = root._indexForEffectId(zoneParam.screenEffectId)
    }
    
    background: Rectangle {
        color: Theme.surface
        radius: Theme.radiusS
        border.color: Theme.border
        border.width: 1
    }

    label: Text {
        text: root.title
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSizeBody
        font.bold: true
        leftPadding: Theme.spacingM
    }

    GridLayout {
        anchors.fill: parent
        columns: 2
        rowSpacing: Theme.spacingL
        columnSpacing: Theme.spacingL
        
        // Zone Name
        Label {
            text: "Nom:"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
        }
        
        TextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: "Nom de la zone"
            text: ""
            
            background: Rectangle {
                color: Theme.background
                radius: Theme.radiusXS
                border.color: nameField.activeFocus ? Theme.accentAlt : Theme.border
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: Theme.durationNormal } }
            }

            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            padding: Theme.spacingS
            
            onEditingFinished: {
                root.configurationChanged()
            }
            Keys.onReturnPressed: {
                focus = false
                root.focusReleased()
            }
        }
        
        // Exclusion Mode
        Label {
            text: "Mode Exclusion:"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
        }
        
        Switch {
            id: exclusionSwitch
            checked: true
            
            indicator: Rectangle {
                implicitWidth: 36
                implicitHeight: 20
                x: exclusionSwitch.leftPadding
                y: parent.height / 2 - height / 2
                radius: 10
                color: exclusionSwitch.checked ? Theme.accentAlt : Theme.surfaceAlt
                border.color: exclusionSwitch.checked ? Theme.accentAlt : Theme.borderLight

                Rectangle {
                    x: exclusionSwitch.checked ? parent.width - width - 2 : 2
                    y: 2
                    width: 16
                    height: 16
                    radius: 8
                    color: "#ffffff"
                    
                    Behavior on x {
                        NumberAnimation { duration: Theme.durationNormal }
                    }
                }
            }
            
            onToggled: {
                root.configurationChanged()
            }
        }

        // Speed Multiplier
        Label {
            text: "Multiplicateur Vitesse:"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
            opacity: exclusionSwitch.checked ? 0.5 : 1.0
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM
            opacity: exclusionSwitch.checked ? 0.5 : 1.0
            enabled: !exclusionSwitch.checked

            Slider {
                id: speedSlider
                Layout.fillWidth: true
                from: 0.1
                to: 3.0
                stepSize: 0.1
                value: 1.0

                background: Rectangle {
                    x: speedSlider.leftPadding
                    y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                    implicitWidth: 100
                    implicitHeight: 4
                    width: speedSlider.availableWidth
                    height: implicitHeight
                    radius: 2
                    color: Theme.surfaceHover

                    Rectangle {
                        width: speedSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#4CAF50"
                        radius: 2
                    }
                }

                handle: Rectangle {
                    x: speedSlider.leftPadding + speedSlider.visualPosition * (speedSlider.availableWidth - width)
                    y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                    implicitWidth: 14
                    implicitHeight: 14
                    radius: 7
                    color: "#ffffff"
                    border.color: "#4CAF50"
                    border.width: 2
                }
                
                onMoved: {
                        root.configurationChanged()
                }
            }
            
            Rectangle {
                Layout.preferredWidth: 45
                height: 26
                radius: Theme.radiusS
                color: Theme.surface
                border.color: "#4CAF50"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "×" + speedSlider.value.toFixed(1)
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }
            }
        }

        // Friction
        Label {
            text: "Friction:"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
            opacity: exclusionSwitch.checked ? 0.5 : 1.0
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM
            opacity: exclusionSwitch.checked ? 0.5 : 1.0
            enabled: !exclusionSwitch.checked

            Slider {
                id: frictionSlider
                Layout.fillWidth: true
                from: 0.0
                to: 1.0
                stepSize: 0.01
                value: 0.0

                background: Rectangle {
                    x: frictionSlider.leftPadding
                    y: frictionSlider.topPadding + frictionSlider.availableHeight / 2 - height / 2
                    implicitWidth: 100
                    implicitHeight: 4
                    width: frictionSlider.availableWidth
                    height: implicitHeight
                    radius: 2
                    color: Theme.surfaceHover

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
                
                onMoved: {
                        root.configurationChanged()
                }
            }
            
            Rectangle {
                Layout.preferredWidth: 45
                height: 26
                radius: Theme.radiusS
                color: Theme.surface
                border.color: "#5DADE2"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: frictionSlider.value.toFixed(2)
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }
            }
        }

        // Acceleration Multiplier
        Label {
            text: "Multiplicateur Accélération:"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
            opacity: exclusionSwitch.checked ? 0.5 : 1.0
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM
            opacity: exclusionSwitch.checked ? 0.5 : 1.0
            enabled: !exclusionSwitch.checked

            Slider {
                id: accelerationSlider
                Layout.fillWidth: true
                from: 0.0
                to: 10.0
                stepSize: 0.05
                value: 1.0

                background: Rectangle {
                    x: accelerationSlider.leftPadding
                    y: accelerationSlider.topPadding + accelerationSlider.availableHeight / 2 - height / 2
                    implicitWidth: 100
                    implicitHeight: 4
                    width: accelerationSlider.availableWidth
                    height: implicitHeight
                    radius: 2
                    color: Theme.surfaceHover

                    Rectangle {
                        width: accelerationSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#FF9800"
                        radius: 2
                    }
                }

                handle: Rectangle {
                    x: accelerationSlider.leftPadding + accelerationSlider.visualPosition * (accelerationSlider.availableWidth - width)
                    y: accelerationSlider.topPadding + accelerationSlider.availableHeight / 2 - height / 2
                    implicitWidth: 14
                    implicitHeight: 14
                    radius: 7
                    color: "#ffffff"
                    border.color: "#FF9800"
                    border.width: 2
                }
                
                onMoved: {
                        root.configurationChanged()
                }
            }
            
            Rectangle {
                Layout.preferredWidth: 45
                height: 26
                radius: Theme.radiusS
                color: Theme.surface
                border.color: "#FF9800"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "×" + accelerationSlider.value.toFixed(2)
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }
            }
        }

        // Effet visuel à l'entrée de zone (bibliothèque MapInfo.screenEffects)
        Label {
            text: "Effet écran:"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
        }

        ComboBox {
            id: effectCombo
            Layout.fillWidth: true
            model: root._effectModel
            textRole: "name"
            currentIndex: root._indexForEffectId(root.screenEffectId)

            // Reflète une liste qui change à chaud (ajout/suppression d'effets).
            Connections {
                target: root
                function on_EffectModelChanged() {
                    effectCombo.currentIndex = root._indexForEffectId(root.screenEffectId)
                }
            }

            onActivated: function(index) {
                const entry = root._effectModel[index]
                const id = entry ? entry.id : ""
                if (root.screenEffectId !== id) {
                    root.screenEffectId = id
                    root.configurationChanged()
                }
            }
        }
    }
}
