import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Game
import EditorOpBus
import theme
import ui_item

/*
 * Section "Combat" du profil joueur : PV max, dégâts, portée et cooldown
 * d'attaque — consommés par le CombatController (contre les EnemyTile).
 * Même pattern d'écriture que PCP_PhysicsSimpleSection : capture
 * before/after via mapInfo.toJSON() + Game.updateMapMetadata (autosave) +
 * broadcast collab UpdatePlayerProfile.
 */
ColumnLayout {
    id: root

    property var profile: null
    property var mapInfo: null

    spacing: Screen.pixelDensity * 1.5

    component CombatSlider: RowLayout {
        id: cbSlider
        property string label
        property string fieldName        // nom JSON du champ (maxHp, ...)
        property string tooltip
        property real minValue
        property real maxValue
        property real step
        property string unitText: ""
        property real value
        property string _beforeJson: ""

        spacing: Screen.pixelDensity * 2

        Label {
            text: cbSlider.label
            color: Theme.textSecondary
            font.pixelSize: Math.round(Screen.pixelDensity * 3)
            Layout.preferredWidth: Screen.pixelDensity * 25
        }
        Rectangle {
            visible: cbSlider.tooltip !== ""
            Layout.preferredWidth: Screen.pixelDensity * 4
            Layout.preferredHeight: Screen.pixelDensity * 4
            radius: width / 2
            color: cbHelpHover.hovered ? Theme.accent : Theme.surfaceHover
            border.color: cbHelpHover.hovered ? Theme.hover(Theme.accent) : Theme.borderLight
            border.width: 1

            Label {
                anchors.centerIn: parent
                text: "?"
                color: Theme.textPrimary
                font.pixelSize: Math.round(Screen.pixelDensity * 2.6)
                font.bold: true
            }
            HoverHandler {
                id: cbHelpHover
                cursorShape: Qt.WhatsThisCursor
            }
            ToolTip.visible: cbHelpHover.hovered
            ToolTip.text: cbSlider.tooltip
            ToolTip.delay: 200
        }
        MeowSlider {
            id: slider
            Layout.fillWidth: true
            showValue: false
            from: cbSlider.minValue
            to: cbSlider.maxValue
            stepSize: cbSlider.step
            value: cbSlider.value
            snapMode: Slider.SnapAlways
            onGestureBegan: cbSlider._beforeJson = root.mapInfo ? root.mapInfo.toJSON() : ""
            onGestureCommitted: root._commit(cbSlider._beforeJson, cbSlider.fieldName, value)
        }
        Label {
            text: slider.value.toFixed(cbSlider.step < 1 ? 1 : 0)
                  + (cbSlider.unitText ? " " + cbSlider.unitText : "")
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

    Label {
        text: "Combat"
        color: Theme.textSecondary
        font.pixelSize: Math.round(Screen.pixelDensity * 3)
        font.bold: true
    }

    CombatSlider {
        Layout.fillWidth: true
        label: "PV max"; fieldName: "maxHp"
        tooltip: "Points de vie maximum du joueur en combat contre les ennemis."
        minValue: 10; maxValue: 500; step: 10
        value: root.profile ? root.profile.maxHp : 100
    }
    CombatSlider {
        Layout.fillWidth: true
        label: "Dégâts"; fieldName: "attackDamage"
        tooltip: "Dégâts infligés à un ennemi par attaque (touche Espace)."
        minValue: 1; maxValue: 100; step: 1
        value: root.profile ? root.profile.attackDamage : 10
    }
    CombatSlider {
        Layout.fillWidth: true
        label: "Portée"; fieldName: "attackRange"
        tooltip: "Portée d'attaque en cellules de grille."
        minValue: 0.5; maxValue: 5.0; step: 0.1
        unitText: "cell."
        value: root.profile ? root.profile.attackRange : 1.5
    }
    CombatSlider {
        Layout.fillWidth: true
        label: "Cooldown"; fieldName: "attackCooldownMs"
        tooltip: "Délai minimum entre deux attaques, en millisecondes."
        minValue: 100; maxValue: 3000; step: 100
        unitText: "ms"
        value: root.profile ? root.profile.attackCooldownMs : 400
    }
}
