import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme

/*
 * Slider étiqueté réutilisable pour l'éditeur d'effets.
 *
 * Le parent lie `value` à une propriété de l'effet et applique les changements :
 *   - begin()       : début d'un geste (capture du snapshot "avant" pour l'undo/save)
 *   - movedValue(v) : valeur live pendant le drag (aperçu immédiat, sans commit)
 *   - commit()      : fin du geste (persistance d'un seul delta)
 */
RowLayout {
    id: root

    property string label: ""
    property real from: 0
    property real to: 1
    property real value: 0
    property int decimals: 2

    signal begin()
    signal movedValue(real v)
    signal commit()

    spacing: Theme.spacingS

    Label {
        text: root.label
        color: Theme.textPrimary
        font.pixelSize: Theme.fontSizeSmall
        font.bold: true
        Layout.preferredWidth: 96
    }

    Slider {
        id: slider
        Layout.fillWidth: true
        from: root.from
        to: root.to
        stepSize: root.decimals >= 2 ? 0.01 : (root.decimals === 1 ? 0.1 : 1)
        value: root.value
        onMoved: root.movedValue(value)
        onPressedChanged: pressed ? root.begin() : root.commit()
    }

    Rectangle {
        Layout.preferredWidth: 48
        height: 24
        radius: Theme.radiusS
        color: Theme.background
        border.color: Theme.border
        border.width: 1
        Text {
            anchors.centerIn: parent
            text: slider.value.toFixed(root.decimals)
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
