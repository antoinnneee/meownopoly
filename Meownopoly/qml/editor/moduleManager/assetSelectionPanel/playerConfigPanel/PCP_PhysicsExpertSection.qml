import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Game
import EditorOpBus
import theme
import ui_item

/*
 * Section "Expert" : 8 sliders complets.
 * Capture before/after via mapInfo.toJSON() autour de la mutation pour
 * Game.updateMapMetadata (autosave) ; broadcast collab via
 * EditorOpBus.submitOp(UpdatePlayerProfile {field: value}).
 */
ColumnLayout {
    id: root

    property var profile: null
    property var mapInfo: null

    spacing: Screen.pixelDensity * 2

    component LabelledSlider: RowLayout {
        id: lblSlider
        property string label
        property string fieldName        // nom JSON du champ
        property string tooltip          // description affichée au survol
        property real minValue
        property real maxValue
        property real step
        property real value
        property int  decimals: 2
        property string _beforeJson: ""

        spacing: Screen.pixelDensity * 2

        Label {
            id: lbl
            text: lblSlider.label
            color: Theme.textSecondary
            font.pixelSize: Math.round(Screen.pixelDensity * 3)
            Layout.preferredWidth: Screen.pixelDensity * 35
        }
        // Bouton d'aide (?) — visible si un tooltip est défini.
        Rectangle {
            id: helpBtn
            visible: lblSlider.tooltip !== ""
            Layout.preferredWidth: Screen.pixelDensity * 4
            Layout.preferredHeight: Screen.pixelDensity * 4
            radius: width / 2
            color: helpHover.hovered ? Theme.accent : Theme.surfaceHover
            border.color: helpHover.hovered ? Theme.hover(Theme.accent) : Theme.borderLight
            border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Label {
                anchors.centerIn: parent
                text: "?"
                color: Theme.textPrimary
                font.pixelSize: Math.round(Screen.pixelDensity * 2.6)
                font.bold: true
            }
            HoverHandler {
                id: helpHover
                cursorShape: Qt.WhatsThisCursor
            }
            ToolTip.visible: helpHover.hovered
            ToolTip.text: lblSlider.tooltip
            ToolTip.delay: 200
        }
        MeowSlider {
            id: slider
            Layout.fillWidth: true
            showValue: false   // label + valeur fournis par LabelledSlider
            from: lblSlider.minValue
            to: lblSlider.maxValue
            stepSize: lblSlider.step
            value: lblSlider.value
            snapMode: Slider.SnapAlways
            onGestureBegan: lblSlider._beforeJson = root.mapInfo ? root.mapInfo.toJSON() : ""
            onGestureCommitted: root._commit(lblSlider._beforeJson, lblSlider.fieldName, value)
        }
        Label {
            text: slider.value.toFixed(lblSlider.decimals)
            color: "#aaaaaa"
            font.pixelSize: Math.round(Screen.pixelDensity * 2.8)
            Layout.preferredWidth: Screen.pixelDensity * 18
            horizontalAlignment: Text.AlignRight
        }
    }

    function _commit(beforeJson, fieldName, value) {
        if (!root.profile || !root.mapInfo || !fieldName) return
        root.profile[fieldName] = value
        Game.updateMapMetadata(beforeJson, root.mapInfo.toJSON())
        const fields = {}
        fields[fieldName] = value
        EditorOpBus.submitOp(EditorOpBus.makeUpdatePlayerProfileOp(
                                root.profile.id, fields))
    }

    LabelledSlider {
        Layout.fillWidth: true
        label: "Taille (radius)"; fieldName: "radius"
        tooltip: "Rayon de collision du body (en unités-grille). Détermine "
               + "aussi la taille apparente du modèle 3D."
        minValue: 0.1; maxValue: 1.5; step: 0.05; decimals: 2
        value: root.profile ? root.profile.radius : 0.4
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Masse"; fieldName: "mass"
        tooltip: "Masse inertielle. Influe sur les chocs body-body : un body "
               + "lourd est moins poussé qu'un léger lors d'une collision."
        minValue: 0.1; maxValue: 10.0; step: 0.1; decimals: 1
        value: root.profile ? root.profile.mass : 1.0
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Accélération"; fieldName: "acceleration"
        tooltip: "Réactivité aux inputs. Détermine la vitesse à laquelle le "
               + "body atteint Vitesse max après une touche pressée."
        minValue: 5; maxValue: 100; step: 1; decimals: 0
        value: root.profile ? root.profile.acceleration : 30
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Vitesse max"; fieldName: "maxSpeed"
        tooltip: "Vitesse maximale (cap soft). Au-delà, le body est freiné "
               + "par le damping jusqu'à revenir au cap."
        minValue: 1; maxValue: 150; step: 1; decimals: 0
        value: root.profile ? root.profile.maxSpeed : 30
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Linear damping"; fieldName: "linearDamping"
        tooltip: "Frottement de base appliqué quand aucun input n'est actif. "
               + "0 = glisse à l'infini, 1 = s'arrête instantanément. Une "
               + "zone friction au sol peut surclasser cette valeur."
        minValue: 0.0; maxValue: 1.0; step: 0.05; decimals: 2
        value: root.profile ? root.profile.linearDamping : 0.1
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Friction statique"; fieldName: "staticFriction"
        tooltip: "Coefficient de Coulomb μ_s utilisé en collision body-body "
               + "et en zone friction. Au-dessus du seuil, la composante "
               + "tangentielle reste collée (stiction). Sans contact, n'a "
               + "pas d'effet — utilise le damping pour freiner un body isolé."
        minValue: 0.0; maxValue: 2.0; step: 0.05; decimals: 2
        value: root.profile ? root.profile.staticFriction : 0.4
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Friction dynamique"; fieldName: "dynamicFriction"
        tooltip: "Coefficient de Coulomb μ_d en glissement actif. Freine la "
               + "composante tangentielle de la velocity au point de contact. "
               + "S'applique seulement en collision body-body ou en zone "
               + "friction."
        minValue: 0.0; maxValue: 2.0; step: 0.05; decimals: 2
        value: root.profile ? root.profile.dynamicFriction : 0.2
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Bounce"; fieldName: "bounceFactor"
        tooltip: "Coefficient de rebond contre les zones d'exclusion (murs). "
               + "0 = le body colle au mur, 1 = rebond parfait."
        minValue: 0.0; maxValue: 1.0; step: 0.05; decimals: 2
        value: root.profile ? root.profile.bounceFactor : 0.1
    }
}
