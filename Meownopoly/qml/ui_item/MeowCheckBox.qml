import QtQuick
import QtQuick.Controls
import theme

/*
 * MeowCheckBox — case à cocher stylée canonique des panneaux de l'éditeur.
 *
 * Indicator carré + "✓", label intégré (contentItem par défaut). Couleur d'accent
 * surchargeable (`accentColor`) pour préserver les variantes existantes
 * (success / violet / accent). Hérite des signaux natifs `toggled()` /
 * `checkedChanged` de CheckBox — le call-site y branche sa logique.
 */
CheckBox {
    id: control

    property color accentColor: Theme.accentAlt

    spacing: Theme.spacingM

    indicator: Rectangle {
        implicitWidth: Theme.px(20)
        implicitHeight: Theme.px(20)
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        radius: Theme.radiusS
        border.width: control.visualFocus ? 2 : 1
        border.color: control.checked ? control.accentColor : Theme.textMuted
        color: control.checked ? control.accentColor : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Text {
            anchors.centerIn: parent
            text: "✓"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeMedium
            font.bold: true
            visible: control.checked
        }
    }

    contentItem: Label {
        text: control.text
        color: control.checked ? Theme.textPrimary : Theme.textSecondary
        font: control.font
        opacity: control.enabled ? 1.0 : 0.4
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + control.spacing
    }
}
