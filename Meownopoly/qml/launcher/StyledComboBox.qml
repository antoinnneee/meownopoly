import QtQuick
import QtQuick.Controls
import theme

/*
 * StyledComboBox.qml — ComboBox custom du projet (thème sombre du launcher).
 *
 * Les ComboBox natifs rendaient un texte sombre sur fond clair (illisible) et
 * un popup non stylé. Ce composant fixe : champ #2a2a2e / border #3a3a3a,
 * texte blanc, popup #1f1f23, item survolé #2f2f2f, item sélectionné accent.
 *
 * `accentColor` est surchargeable (défaut vert projet #569c58).
 */
ComboBox {
    id: control

    property color accentColor: Theme.accentAlt

    implicitHeight: 32
    leftPadding: Theme.spacingL
    rightPadding: 28

    font.pixelSize: Theme.fontSizeBody

    contentItem: Text {
        leftPadding: control.leftPadding
        rightPadding: control.rightPadding
        text: control.displayText
        color: control.enabled ? Theme.textPrimary : Theme.textHint
        font: control.font
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignLeft
        elide: Text.ElideRight
    }

    indicator: Text {
        x: control.width - width - 8
        y: control.topPadding + (control.availableHeight - height) / 2
        text: "▾"
        color: control.popup.visible ? control.accentColor : Theme.textHint
        font.pixelSize: Theme.fontSizeMedium
    }

    background: Rectangle {
        color: control.pressed ? Theme.background : Theme.surface
        radius: Theme.radiusXS
        border.color: control.activeFocus ? control.accentColor : Theme.border
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    delegate: ItemDelegate {
        id: itemDel
        width: control.width
        contentItem: Text {
            text: modelData
            color: itemDel.highlighted ? Theme.textPrimary : Theme.textSecondary
            font: control.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            color: itemDel.highlighted
                     ? control.accentColor
                     : (itemDel.hovered ? Theme.surfaceAlt : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }
        highlighted: control.highlightedIndex === index
    }

    popup: Popup {
        y: control.height - 1
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight, 240)
        padding: 1

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex

            ScrollIndicator.vertical: ScrollIndicator {}
        }

        background: Rectangle {
            color: Theme.background
            border.color: Theme.border
            border.width: 1
            radius: Theme.radiusXS
        }
    }
}
