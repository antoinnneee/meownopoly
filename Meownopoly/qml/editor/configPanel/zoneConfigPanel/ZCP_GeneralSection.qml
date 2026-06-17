import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import theme
import ui_item
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
        frictionSlider.value = zoneParam.frictionStrength
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
        
        MeowTextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: "Nom de la zone"
            text: ""

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

        MeowSwitch {
            id: exclusionSwitch
            checked: true

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
        
        MeowSlider {
            id: speedSlider
            Layout.fillWidth: true
            opacity: exclusionSwitch.checked ? 0.5 : 1.0
            enabled: !exclusionSwitch.checked

            from: 0.1
            to: 3.0
            stepSize: 0.1
            value: 1.0
            decimals: 1
            unitText: "×"
            accentColor: Theme.success

            onMoved: root.configurationChanged()
        }

        // Friction
        Label {
            text: "Friction:"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
            opacity: exclusionSwitch.checked ? 0.5 : 1.0
        }
        
        MeowSlider {
            id: frictionSlider
            Layout.fillWidth: true
            opacity: exclusionSwitch.checked ? 0.5 : 1.0
            enabled: !exclusionSwitch.checked

            from: 0.0
            to: 1.0
            stepSize: 0.01
            value: 0.0
            decimals: 2
            accentColor: "#5DADE2"

            onMoved: root.configurationChanged()
        }

        // Acceleration Multiplier
        Label {
            text: "Multiplicateur Accélération:"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
            opacity: exclusionSwitch.checked ? 0.5 : 1.0
        }
        
        MeowSlider {
            id: accelerationSlider
            Layout.fillWidth: true
            opacity: exclusionSwitch.checked ? 0.5 : 1.0
            enabled: !exclusionSwitch.checked

            from: 0.0
            to: 10.0
            stepSize: 0.05
            value: 1.0
            decimals: 2
            unitText: "×"
            accentColor: Theme.warning

            onMoved: root.configurationChanged()
        }

        // Effet visuel à l'entrée de zone (bibliothèque MapInfo.screenEffects)
        Label {
            text: "Effet écran:"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
        }

        MeowComboBox {
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
